import Foundation
import Testing
@testable import iRead

@Suite("PageContent")
struct PageContentTests {
    private func page(_ number: Int) -> Page {
        Page(number: number, chapterIndex: 0, range: NSRange(location: number * 10, length: 10), text: "page \(number)")
    }

    private func content(loaded numbers: [Int], shown: Int) -> PageContent {
        PageContent(pages: numbers.map(page), shownPage: page(shown), settings: ReadingSettings(), horizontalMargin: 0,
                    marks: [:], chrome: { _ in PageChrome() }, frames: PageFrames(), selectedUnderlineID: nil)
    }

    @Test("RD-36 the neighbor is the loaded page before or after, and nil where none is loaded")
    func neighbor() {
        let content = content(loaded: [4, 5, 6], shown: 5)
        #expect(content.neighbor(of: page(5), isForward: true) == page(6))
        #expect(content.neighbor(of: page(5), isForward: false) == page(4))
        // The edges of what is loaded, and a book's first page: nothing to turn to.
        #expect(content.neighbor(of: page(6), isForward: true) == nil)
        #expect(content.neighbor(of: page(4), isForward: false) == nil)
    }
}
