import Foundation

/// What a page shows above and below its text: the book and chapter on top, the page label at the bottom.
/// Each page carries its own, so they turn with the page, like Apple Books.
struct PageChrome: Equatable, Sendable {
    var title = ""
    var chapterTitle = ""
    var pageLabel = ""
    var isReadingMode = false

    var readingModeDescription: String {
        isReadingMode ? "Reading mode on. References hidden." : "Reading mode off. Available references are underlined."
    }
}

/// A navigation event creates one focus request shared by both page renderers.
struct ReaderFocusRequest: Equatable {
    enum Target: Equatable { case heading, content, chapterAndContent, passage(String) }
    let id = UUID()
    let target: Target

    init(from previous: Page?, to page: Page, passage: String? = nil) {
        if let passage, !passage.isEmpty {
            target = .passage(passage)
        } else if let previous {
            target = previous.chapterIndex == page.chapterIndex ? .content : .chapterAndContent
        } else {
            target = .heading
        }
    }
}

/// Everything the pagers need to draw the pages: the one input of both `PageTurnView` (Curl) and `PageSlideView`
/// (Slide and Fast Fade). Plain data, built by `ReaderVM`, so a pager can tell when nothing changed.
struct PageContent: Equatable {
    var pages: [Page]
    var shownPage: Page
    var settings: ReadingSettings
    var layout: PageLayout
    var marks: [Int: [Mark]]
    /// By page number, for every page in `pages` and for `shownPage`.
    var chromes: [Int: PageChrome]
    /// The underline last tapped, if any: it stays highlighted.
    var selectedUnderlineID: String?
    var readingFocus: ReaderFocusRequest?

    var horizontalMargin: CGFloat {
        layout.horizontalMargin
    }

    func marks(on page: Page) -> [Mark] {
        marks[page.number, default: []]
    }

    func chrome(of page: Page) -> PageChrome {
        chromes[page.number, default: PageChrome()]
    }

    /// The loaded page before or after `page`, nil when it isn't loaded (or there is none).
    func neighbor(of page: Page, isForward: Bool) -> Page? {
        let number = page.number + (isForward ? 1 : -1)
        return pages.first { $0.number == number }
    }

    /// The ranges of `page` that get a highlight behind them: a jumped-to passage or search result, and the underline last tapped.
    func highlights(on page: Page) -> [NSRange] {
        let marks = marks(on: page)
        let passages = marks.filter { $0.kind == .highlight }.map(\.range)
        let selected = selectedUnderlineID.flatMap { id in marks.first { $0.underlineID == id }?.range }
        return passages + [selected].compactMap { $0 }
    }
}
