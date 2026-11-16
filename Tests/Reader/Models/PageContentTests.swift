import Foundation
import Testing
@testable import iRead

@Suite("PageContent")
struct PageContentTests {
    private let layout = PageLayout(ScreenGeometry(safeSize: CGSize(width: 440, height: 860), safeAreaTop: 62, safeAreaBottom: 34))

    private func page(_ number: Int) -> Page {
        Page(number: number, chapterIndex: 0, range: NSRange(location: number * 10, length: 10), text: "page \(number)")
    }

    private func content(loaded numbers: [Int] = [4, 5, 6], shown: Int = 5, marks: [Int: [Mark]] = [:],
                         selected: String? = nil) -> PageContent {
        PageContent(pages: numbers.map(page), shownPage: page(shown), settings: ReadingSettings(), layout: layout,
                    marks: marks, chromes: [:], selectedUnderlineID: selected)
    }

    @Test("RD-36 the neighbor is the loaded page before or after, and nil where none is loaded")
    func neighbor() {
        let content = content()
        #expect(content.neighbor(of: page(5), isForward: true) == page(6))
        #expect(content.neighbor(of: page(5), isForward: false) == page(4))
        // The edges of what is loaded, and a book's first page: nothing to turn to.
        #expect(content.neighbor(of: page(6), isForward: true) == nil)
        #expect(content.neighbor(of: page(4), isForward: false) == nil)
    }

    @Test("RD-38 a jumped-to passage and the underline last tapped get a highlight; a tapped underline on another page does not")
    func highlights() {
        let marks = [5: [
            Mark(range: NSRange(location: 0, length: 3), kind: .underline(id: "a")),
            Mark(range: NSRange(location: 5, length: 2), kind: .highlight),
            Mark(range: NSRange(location: 9, length: 1), kind: .underline(id: "b"))
        ]]
        #expect(content(marks: marks, selected: "a").highlights(on: page(5)) == [NSRange(location: 5, length: 2), NSRange(location: 0, length: 3)])
        // Nothing tapped yet, or the tapped underline is on another page: only the passage.
        #expect(content(marks: marks).highlights(on: page(5)) == [NSRange(location: 5, length: 2)])
        #expect(content(marks: marks, selected: "elsewhere").highlights(on: page(5)) == [NSRange(location: 5, length: 2)])
        #expect(content(marks: marks, selected: "a").highlights(on: page(6)).isEmpty)
    }

    @Test("RD-39 a page's chrome is looked up by its number, and is empty when none was built")
    func chrome() {
        var content = content()
        content.chromes = [5: PageChrome(title: "Anne", chapterTitle: "CHAPTER I", pageLabel: "Page 5")]
        #expect(content.chrome(of: page(5)).pageLabel == "Page 5")
        #expect(content.chrome(of: page(6)) == PageChrome())
    }
}
