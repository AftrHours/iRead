import Foundation
import Testing
@testable import iRead

@Suite("ReaderCtrl")
struct ReaderCtrlTests {
    private let folder = TempFolder()
    /// About 140 characters per chapter, so 5 pages each at 30 characters a page.
    private let content = BookContent.make(chapters: [
        ["Chapter one starts here and goes on for a while.", "A second paragraph in the first chapter.", "The third paragraph closes chapter one."],
        ["Chapter two opens with this line of text.", "Then a middle paragraph follows it.", "And the last paragraph of the book ends here."]
    ])

    private func makeReader(content: BookContent? = nil) async throws -> (ReaderCtrl, PagerSvcFixed) {
        let pager = PagerSvcFixed(pageLength: 30)
        let repo = BookContentRepo(epubParseSvc: EPUBParseSvcSpy(content: content ?? self.content), folder: folder.url)
        let ctrl = ReaderCtrl(bookID: sampleID, bookContentRepo: repo, pagerSvc: pager)
        try await ctrl.openBook()
        return (ctrl, pager)
    }

    private func page(_ page: Page, contains position: ReadingPosition) -> Bool {
        let paragraph = content.paragraphs[position.paragraph]
        let offset = paragraph.range.location + position.charOffset
        return page.chapterIndex == paragraph.chapterIndex && NSLocationInRange(offset, page.range)
    }

    @Test("RD-01 a valid saved position is restored")
    func restoreValid() async throws {
        let (ctrl, _) = try await makeReader()
        let position = ReadingPosition(paragraph: 4, charOffset: 10)
        #expect(await ctrl.restorePosition(from: .make(paragraph: 4, charOffset: 10, chapterIndex: 1)))
        #expect(page(await ctrl.currentPage(viewport: iPadViewport, settings: ReadingSettings()), contains: position))
    }

    @Test("RD-02 an invalid position opens at the start of the saved chapter", arguments: [(99, 0), (4, 999)])
    func restoreInvalid(paragraph: Int, charOffset: Int) async throws {
        let (ctrl, _) = try await makeReader()
        #expect(await !ctrl.restorePosition(from: .make(paragraph: paragraph, charOffset: charOffset, chapterIndex: 1)))
        let current = await ctrl.currentPage(viewport: iPadViewport, settings: ReadingSettings())
        #expect(current.chapterIndex == 1)
        #expect(current.range.location == 0)
    }

    @Test("RD-03 an invalid position and chapter open chapter 1")
    func restoreInvalidChapter() async throws {
        let (ctrl, _) = try await makeReader()
        #expect(await !ctrl.restorePosition(from: .make(paragraph: 99, chapterIndex: 99)))
        let current = await ctrl.currentPage(viewport: iPadViewport, settings: ReadingSettings())
        #expect(current.chapterIndex == 0)
        #expect(current.range.location == 0)
    }

    @Test("RD-04 pages(around:) loads 2 pages on each side when there are any")
    func pagesAround() async throws {
        let (ctrl, _) = try await makeReader()
        _ = await ctrl.currentPage(viewport: iPadViewport, settings: ReadingSettings())
        let first = await ctrl.firstPage(ofChapter: 0)
        let aroundFirst = await ctrl.pages(around: first)
        #expect(aroundFirst.map(\.number) == [1, 2, 3])

        let middle = aroundFirst[2]
        #expect(await ctrl.pages(around: middle).map(\.number) == [1, 2, 3, 4, 5])

        _ = await ctrl.restorePosition(from: .make(paragraph: 5, charOffset: content.paragraphs[5].range.length, chapterIndex: 1))
        let last = await ctrl.currentPage(viewport: iPadViewport, settings: ReadingSettings())
        let total = await ctrl.chapterPageCounts().reduce(0, +)
        #expect(last.number == total)
        #expect(await ctrl.pages(around: last).map(\.number) == [total - 2, total - 1, total])
    }

    @Test("RD-05 the page after a chapter's last page is the next chapter's first, numbered on")
    func nextChapter() async throws {
        let (ctrl, _) = try await makeReader()
        _ = await ctrl.currentPage(viewport: iPadViewport, settings: ReadingSettings())
        let firstOfChapterTwo = await ctrl.firstPage(ofChapter: 1)
        let lastOfChapterOne = await ctrl.pages(around: firstOfChapterTwo)[1]
        #expect(lastOfChapterOne.chapterIndex == 0)
        #expect(NSMaxRange(lastOfChapterOne.range) == content.chapters[0].text.utf16.count)

        let around = await ctrl.pages(around: lastOfChapterOne)
        let next = try #require(around.firstIndex(of: lastOfChapterOne).map { around[$0 + 1] })
        #expect(next == firstOfChapterTwo)
        #expect(next.range.location == 0)
        #expect(next.number == lastOfChapterOne.number + 1)
    }

    @Test("RD-06 a layout change lays pages out again and keeps the position",
          arguments: ["text size", "line spacing", "theme", "viewport"])
    func layoutChange(change: String) async throws {
        let (ctrl, pager) = try await makeReader()
        let position = ReadingPosition(paragraph: 4, charOffset: 10)
        _ = await ctrl.restorePosition(from: .make(paragraph: 4, charOffset: 10, chapterIndex: 1))
        _ = await ctrl.currentPage(viewport: iPadViewport, settings: ReadingSettings())
        let layouts = pager.layoutCount

        var settings = ReadingSettings()
        var viewport = iPadViewport
        switch change {
        case "text size": settings.textSizeIndex += 1
        case "line spacing": settings.lineSpacingPercent += 5
        case "theme": settings.theme = .paper
        default: viewport = Viewport(size: CGSize(width: 1180, height: 820))
        }
        let current = await ctrl.currentPage(viewport: viewport, settings: settings)
        #expect(pager.layoutCount > layouts)
        #expect(page(current, contains: position))
    }

    @Test("RD-08 range(from:length:on:) is page-relative, nil off the page, and clipped at its end")
    func rangeOnPage() async throws {
        let (ctrl, _) = try await makeReader()
        _ = await ctrl.currentPage(viewport: iPadViewport, settings: ReadingSettings())
        let first = await ctrl.firstPage(ofChapter: 0)
        let second = await ctrl.pages(around: first)[1]
        #expect(await ctrl.range(from: ReadingPosition(paragraph: 0, charOffset: 5), length: 4, on: first) == NSRange(location: 5, length: 4))
        #expect(await ctrl.range(from: ReadingPosition(paragraph: 0, charOffset: 35), length: 4, on: second) == NSRange(location: 5, length: 4))
        #expect(await ctrl.range(from: ReadingPosition(paragraph: 3, charOffset: 0), length: 4, on: first) == nil)
        #expect(await ctrl.range(from: ReadingPosition(paragraph: 0, charOffset: 25), length: 10, on: first) == NSRange(location: 25, length: 5))
    }

    @Test("RD-09 turning to a page saves its start and makes it the current page")
    func pageChanged() async throws {
        let (ctrl, _) = try await makeReader()
        _ = await ctrl.currentPage(viewport: iPadViewport, settings: ReadingSettings())
        let turnedTo = await ctrl.page(containing: ReadingPosition(paragraph: 4, charOffset: 20))
        let progress = await ctrl.pageChanged(to: turnedTo)
        #expect(progress.position == (await ctrl.startPosition(of: turnedTo)))
        #expect(progress.chapterIndex == 1)
        #expect(await ctrl.currentPage(viewport: iPadViewport, settings: ReadingSettings()) == turnedTo)
    }

    @Test("RD-16 a search result's page number is the page that contains it")
    func searchPageNumber() async throws {
        let chapters = (1...4).map { number in
            ["Chapter \(number) has a long opening paragraph to fill some pages.", "Nothing special happens here at all."]
        }
        var withMatch = chapters
        withMatch[3][1] = "Then the zebra walked in, quite late."
        let content = BookContent.make(chapters: withMatch)
        let (ctrl, _) = try await makeReader(content: content)
        _ = await ctrl.currentPage(viewport: iPadViewport, settings: ReadingSettings())

        let result = try #require(await ctrl.search("zebra").first)
        #expect(content.paragraphs[result.position.paragraph].chapterIndex == 3)
        #expect(result.pageNumber == (await ctrl.page(containing: result.position)).number)
    }

    @Test("RD-25 a cancelled search finds nothing and lays out no more chapters")
    func cancelledSearch() async throws {
        let (ctrl, pager) = try await makeReader()
        _ = await ctrl.currentPage(viewport: iPadViewport, settings: ReadingSettings())
        let layoutsBefore = pager.layoutCount

        let search = Task {
            try? await Task.sleep(for: .seconds(10))
            return await ctrl.search("chapter")
        }
        search.cancel()
        #expect(await search.value.isEmpty)
        #expect(pager.layoutCount == layoutsBefore)
        #expect(await !ctrl.search("chapter").isEmpty)
    }
}
