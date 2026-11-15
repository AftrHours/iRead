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
