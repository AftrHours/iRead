import Foundation

actor ReaderCtrl {
    private let bookID: UUID
    private let bookContentRepo: BookContentRepo
    private let pagerSvc: PagerSvc

    private var content = BookContent(chapters: [], paragraphs: [], sentences: [], parserVersion: 0)
    private var readingSettings = ReadingSettings()
    private var viewport = Viewport(size: .zero)
    private var position = ReadingPosition(paragraph: 0, charOffset: 0)
    private var chapterPages: [[NSRange]] = []

    init(bookID: UUID, bookContentRepo: BookContentRepo, pagerSvc: PagerSvc) {
        self.bookID = bookID
        self.bookContentRepo = bookContentRepo
        self.pagerSvc = pagerSvc
    }

    func openBook() async throws {
        content = try await bookContentRepo.content(for: bookID)
    }

    func restorePosition(from readingProgress: ReadingProgress) -> Bool {
        let isRestored = isValid(readingProgress.position)
        let chapterIndex = content.chapters.indices.contains(readingProgress.chapterIndex) ? readingProgress.chapterIndex : 0
        position = isRestored
            ? readingProgress.position
            : ReadingPosition(paragraph: content.chapters[chapterIndex].paragraphs.lowerBound, charOffset: 0)
        return isRestored
    }

    func chapterTitles() -> [String] {
        content.chapters.map(\.title)
    }

    func currentPage(viewport: Viewport, settings: ReadingSettings) async -> Page {
        let isLayoutChanged = viewport != self.viewport || !settings.hasSameLayout(as: readingSettings)
        self.viewport = viewport
        readingSettings = settings
        if isLayoutChanged {
            chapterPages = []
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

    func pageChanged(to page: Page) -> ReadingProgress {
        position = startPosition(of: page)
        return ReadingProgressCalculator.progress(on: page, in: content, bookID: bookID, at: .now)
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

    func startPosition(of page: Page) -> ReadingPosition {
        ReadingProgressCalculator.position(chapterIndex: page.chapterIndex, offset: page.range.location, in: content)
    }

    func page(ifValid position: ReadingPosition) async -> Page? {
        guard isValid(position) else { return nil }
        return await page(containing: position)
    }

    private func isValid(_ position: ReadingPosition) -> Bool {
        content.paragraphs.indices.contains(position.paragraph)
            && (0...content.paragraphs[position.paragraph].range.length).contains(position.charOffset)
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
