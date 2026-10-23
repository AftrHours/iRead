import Foundation

actor ReaderCtrlLive: ReaderCtrl {
    private let bookID: UUID
    private let libRepo: any LibRepo
    private let bookContentRepo: any BookContentRepo
    private let pagerSvc: any PagerSvc
    private let progRepo: any ProgRepo
    private let eventSvc: any EventSvc

    private var content = BookContent(chapters: [], paragraphs: [], sentences: [], parserVersion: 0)
    private let settings = ReadingSettings()
    private var viewport = Viewport(size: .zero, bodyFontSize: 0)
    private var position = ReadingPosition(paragraph: 0, charOffset: 0)
    private var chapterPages: [[NSRange]] = []
    private var readingProgress: ReadingProgress?

    init(bookID: UUID, libRepo: any LibRepo, bookContentRepo: any BookContentRepo, pagerSvc: any PagerSvc,
         progRepo: any ProgRepo, eventSvc: any EventSvc) {
        self.bookID = bookID
        self.libRepo = libRepo
        self.bookContentRepo = bookContentRepo
        self.pagerSvc = pagerSvc
        self.progRepo = progRepo
        self.eventSvc = eventSvc
    }

    func openBook() async throws -> BookRecord {
        guard let book = try await libRepo.fetchBooks().first(where: { $0.id == bookID }) else {
            throw ContentError.notFound
        }
        content = try await bookContentRepo.content(for: bookID)
        readingProgress = await progRepo.progress(for: bookID)
        if let readingProgress {
            let isRestored = isValid(readingProgress.position)
            let chapterIndex = content.chapters.indices.contains(readingProgress.chapterIndex) ? readingProgress.chapterIndex : 0
            position = isRestored
                ? readingProgress.position
                : ReadingPosition(paragraph: content.chapters[chapterIndex].paragraphs.lowerBound, charOffset: 0)
            await eventSvc.log(.positionRestore(bookID: bookID, isRestored: isRestored))
        }
        return book
    }

    func chapterTitles() -> [String] {
        content.chapters.map(\.title)
    }

    func currentPage(viewport: Viewport) async -> Page {
        if viewport != self.viewport {
            self.viewport = viewport
            chapterPages = []
        }
        let paragraph = content.paragraphs[position.paragraph]
        return await page(chapterIndex: paragraph.chapterIndex, offset: paragraph.range.location + position.charOffset)
    }

    func pages(around page: Page) async -> [Page] {
        var pages = [page]
        for _ in 0..<2 {
            if let previous = await self.page(before: pages[0]) {
                pages.insert(previous, at: 0)
            }
            if let next = await self.page(after: pages[pages.count - 1]) {
                pages.append(next)
            }
        }
        return pages
    }

    func firstPage(ofChapter index: Int) async -> Page {
        await page(chapterIndex: index, offset: 0)
    }

    func chapterPageCounts() async -> [Int] {
        await paginate(through: content.chapters.count - 1)
        return chapterPages.map(\.count)
    }

    func pageChanged(to page: Page) async {
        position = position(chapterIndex: page.chapterIndex, offset: page.range.location)
        let pageEnd = position(chapterIndex: page.chapterIndex, offset: NSMaxRange(page.range))
        let lastVisibleSentence = content.sentences.lastIndex {
            ReadingPosition(paragraph: $0.paragraph, charOffset: $0.range.location) < pageEnd
        } ?? 0
        let wordsBefore = content.paragraphs[..<position.paragraph].reduce(0) { $0 + $1.wordCount }
        let totalWords = content.paragraphs.reduce(0) { $0 + $1.wordCount }
        let progress = Double(wordsBefore) / Double(totalWords)
        let isLastPage = page.chapterIndex == content.chapters.count - 1
            && NSMaxRange(page.range) == content.chapters[page.chapterIndex].text.utf16.count
        let wasFinished = self.readingProgress?.finishedAt != nil
        let readingProgress = ReadingProgress(
            bookID: bookID,
            position: position,
            chapterIndex: page.chapterIndex,
            progress: progress,
            lastReadAt: .now,
            readingFrontier: FrontierRule.frontier(old: self.readingProgress?.readingFrontier ?? 0, lastVisibleSentence: lastVisibleSentence),
            finishedAt: self.readingProgress?.finishedAt ?? (isLastPage || progress >= 0.99 ? .now : nil)
        )
        self.readingProgress = readingProgress
        await progRepo.save(readingProgress)
        if !wasFinished, readingProgress.finishedAt != nil {
            await eventSvc.log(.bookFinished(bookID: bookID))
        }
    }

    func saveNow() async {
        guard let readingProgress else { return }
        await progRepo.saveNow(readingProgress)
    }

    private func isValid(_ position: ReadingPosition) -> Bool {
        content.paragraphs.indices.contains(position.paragraph)
            && (0...content.paragraphs[position.paragraph].range.length).contains(position.charOffset)
    }

    private func position(chapterIndex: Int, offset: Int) -> ReadingPosition {
        let chapter = content.chapters[chapterIndex]
        let paragraph = chapter.paragraphs.last { content.paragraphs[$0].range.location <= offset } ?? chapter.paragraphs.lowerBound
        return ReadingPosition(paragraph: paragraph, charOffset: offset - content.paragraphs[paragraph].range.location)
    }

    private func page(after page: Page) async -> Page? {
        let end = NSMaxRange(page.range)
        if end < content.chapters[page.chapterIndex].text.utf16.count {
            return await self.page(chapterIndex: page.chapterIndex, offset: end)
        }
        guard page.chapterIndex + 1 < content.chapters.count else { return nil }
        return await self.page(chapterIndex: page.chapterIndex + 1, offset: 0)
    }

    private func page(before page: Page) async -> Page? {
        if page.range.location > 0 {
            return await self.page(chapterIndex: page.chapterIndex, offset: page.range.location - 1)
        }
        guard page.chapterIndex > 0 else { return nil }
        return await self.page(chapterIndex: page.chapterIndex - 1, offset: .max)
    }

    private func page(chapterIndex: Int, offset: Int) async -> Page {
        await paginate(through: chapterIndex)
        let ranges = chapterPages[chapterIndex]
        let index = ranges.lastIndex { $0.location <= offset } ?? 0
        let pagesBefore = chapterPages[..<chapterIndex].reduce(0) { $0 + $1.count }
        let text = (content.chapters[chapterIndex].text as NSString).substring(with: ranges[index])
        return Page(number: pagesBefore + index + 1, chapterIndex: chapterIndex, range: ranges[index], text: text)
    }

    private func paginate(through chapterIndex: Int) async {
        while chapterPages.count <= chapterIndex {
            let next = chapterPages.count
            let viewport = self.viewport
            let ranges = await pagerSvc.pageRanges(for: content.chapters[next].text, viewport: viewport, settings: settings)
            // Another call may have laid out this chapter, or the viewport may have changed, while waiting.
            if chapterPages.count == next, viewport == self.viewport {
                chapterPages.append(ranges)
            }
        }
    }
}
