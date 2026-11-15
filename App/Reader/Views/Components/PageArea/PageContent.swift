import CoreGraphics

/// What a page shows above and below its text: the book and chapter on top, the page label at the bottom.
/// Each page carries its own, so they turn with the page, like Apple Books.
struct PageChrome: Equatable {
    var title = ""
    var chapterTitle = ""
    var pageLabel = ""
}

/// Where a full-screen page puts its parts: the header (where the top bar's titles sit), the text, and the footer
/// (where the bottom bar's page label sits). In the page's own coordinates.
struct PageFrames: Equatable {
    var header: CGRect = .zero
    var text: CGRect = .zero
    var footer: CGRect = .zero

    /// The same frames, measured somewhere else, seen from a view whose origin sits at `origin` there.
    func relative(to origin: CGPoint) -> PageFrames {
        PageFrames(header: header.offsetBy(dx: -origin.x, dy: -origin.y),
                   text: text.offsetBy(dx: -origin.x, dy: -origin.y),
                   footer: footer.offsetBy(dx: -origin.x, dy: -origin.y))
    }
}

/// Everything the pagers need to draw the pages: the one input of both `PageTurnView` (Curl) and `PageSlideView`
/// (Slide and Fast Fade), so a page is built, matched and neighbored the same way in each.
struct PageContent {
    var pages: [Page]
    var shownPage: Page
    var settings: ReadingSettings
    var horizontalMargin: CGFloat
    var marks: [Int: [Mark]]
    var chrome: (Page) -> PageChrome
    var frames: PageFrames
    /// The underline last tapped, if any: it stays highlighted.
    var selectedUnderlineID: String?

    func marks(on page: Page) -> [Mark] {
        marks[page.number, default: []]
    }

    /// The loaded page before or after `page`, nil when it isn't loaded (or there is none).
    func neighbor(of page: Page, isForward: Bool) -> Page? {
        let number = page.number + (isForward ? 1 : -1)
        return pages.first { $0.number == number }
    }
}

/// What a page tells the reader: the page turned, the middle tapped, an underline tapped.
struct PageActions {
    var onPageChanged: (Page) -> Void
    var onCenterTapped: () -> Void
    var onMarkTapped: (Mark, CGRect) -> Void

    static var none: PageActions {
        PageActions(onPageChanged: { _ in }, onCenterTapped: {}, onMarkTapped: { _, _ in })
    }
}
