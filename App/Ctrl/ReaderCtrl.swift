import Foundation

actor ReaderCtrl {
    private let bookID: UUID
    private let libRepo: LibRepo
    private let bookContentRepo: BookContentRepo
    private let pagerSvc: PagerSvc
    private let progRepo: ProgRepo
    private let eventSvc: EventSvc
    private let readingSettingsRepo: ReadingSettingsRepo
    private let brightnessSvc: BrightnessSvc
    private let bookStateRepo: BookStateRepo

    private var content = BookContent(chapters: [], paragraphs: [], sentences: [], parserVersion: 0)
    private var readingSettings = ReadingSettings()
    private var viewport = Viewport(size: .zero, bodyFontSize: 0)
    private var position = ReadingPosition(paragraph: 0, charOffset: 0)
    private var chapterPages: [[NSRange]] = []
    private var readingProgress: ReadingProgress?
    private var bookState = BookState()

    init(bookID: UUID, libRepo: LibRepo, bookContentRepo: BookContentRepo, pagerSvc: PagerSvc,
         progRepo: ProgRepo, eventSvc: EventSvc, readingSettingsRepo: ReadingSettingsRepo, brightnessSvc: BrightnessSvc,
         bookStateRepo: BookStateRepo) {
        self.bookID = bookID
        self.libRepo = libRepo
        self.bookContentRepo = bookContentRepo
        self.pagerSvc = pagerSvc
        self.progRepo = progRepo
        self.eventSvc = eventSvc
        self.readingSettingsRepo = readingSettingsRepo
        self.brightnessSvc = brightnessSvc
        self.bookStateRepo = bookStateRepo
    }

    func openBook() async throws -> BookRecord {
        guard let book = try await libRepo.fetchBooks().first(where: { $0.id == bookID }) else {
            throw ContentError.notFound
        }
        content = try await bookContentRepo.content(for: bookID)
        readingSettings = await readingSettingsRepo.settings()
        readingProgress = await progRepo.progress(for: bookID)
        bookState = await bookStateRepo.state(for: bookID)
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

    func settings() -> ReadingSettings {
        readingSettings
    }

    func currentPage(viewport: Viewport, settings: ReadingSettings) async -> Page {
        let isLayoutChanged = viewport != self.viewport
            || settings.textSizeStep != readingSettings.textSizeStep
            || settings.lineSpacingStep != readingSettings.lineSpacingStep
        let isSettingsChanged = settings != readingSettings
        self.viewport = viewport
        readingSettings = settings
        if isLayoutChanged {
            chapterPages = []
        }
        if isSettingsChanged {
            await readingSettingsRepo.save(settings)
        }
        return await page(containing: position)
    }

    func page(containing position: ReadingPosition) async -> Page {
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
            readingFrontier: max(self.readingProgress?.readingFrontier ?? 0, lastVisibleSentence),
            finishedAt: self.readingProgress?.finishedAt ?? (isLastPage || progress >= 0.99 ? .now : nil)
        )
        self.readingProgress = readingProgress
        await progRepo.save(readingProgress)
        if !wasFinished, readingProgress.finishedAt != nil {
            await eventSvc.log(.bookFinished(bookID: bookID))
        }
    }

    func search(_ query: String) async -> [SearchResult] {
        let matches = BookSearch.matches(of: query, in: content)
        await paginate(through: content.chapters.count - 1)
        return matches.map { match in
            let paragraph = content.paragraphs[match.position.paragraph]
            let chapterIndex = paragraph.chapterIndex
            let pageIndex = pageIndex(chapterIndex: chapterIndex, offset: paragraph.range.location + match.position.charOffset)
            return SearchResult(
                chapterTitle: content.chapters[chapterIndex].title,
                snippet: match.snippet,
                position: match.position,
                pageNumber: pagesBefore(chapterIndex: chapterIndex) + pageIndex + 1
            )
        }
    }

    func hasReturnPosition() -> Bool {
        bookState.returnPosition != nil
    }

    func saveReturnPosition(from page: Page) async {
        guard bookState.returnPosition == nil else { return }
        bookState.returnPosition = position(chapterIndex: page.chapterIndex, offset: page.range.location)
        await bookStateRepo.save(bookState, for: bookID)
    }

    func returnPage() async -> Page? {
        guard let returnPosition = bookState.returnPosition, isValid(returnPosition) else { return nil }
        return await page(containing: returnPosition)
    }

    func clearReturnPosition() async {
        bookState.returnPosition = nil
        await bookStateRepo.save(bookState, for: bookID)
    }

    func brightness() async -> Double {
        await brightnessSvc.brightness()
    }

    func changeBrightness(to value: Double) async {
        await brightnessSvc.changeBrightness(to: value)
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
        let index = pageIndex(chapterIndex: chapterIndex, offset: offset)
        let range = chapterPages[chapterIndex][index]
        let text = (content.chapters[chapterIndex].text as NSString).substring(with: range)
        return Page(number: pagesBefore(chapterIndex: chapterIndex) + index + 1, chapterIndex: chapterIndex, range: range, text: text)
    }

    private func pageIndex(chapterIndex: Int, offset: Int) -> Int {
        chapterPages[chapterIndex].lastIndex { $0.location <= offset } ?? 0
    }

    private func pagesBefore(chapterIndex: Int) -> Int {
        chapterPages[..<chapterIndex].reduce(0) { $0 + $1.count }
    }

    private func paginate(through chapterIndex: Int) async {
        while chapterPages.count <= chapterIndex {
            let next = chapterPages.count
            let viewport = self.viewport
            let settings = readingSettings
            let ranges = await pagerSvc.pageRanges(for: content.chapters[next].text, viewport: viewport, settings: settings)
            // Another call may have laid out this chapter, or the layout may have changed, while waiting.
            if chapterPages.count == next, viewport == self.viewport, settings == readingSettings {
                chapterPages.append(ranges)
            }
        }
    }
}
