import CoreGraphics

/// The numbers that place a full-screen page's parts. The top and bottom bars take their height and side margin from here too,
/// so the titles, the text and the page label sit where the buttons leave room for them.
enum PageLayoutKnobs {
    /// The × and ••• buttons are this tall, and the titles and page label are centred on a bar this tall.
    static let barHeight: CGFloat = 44
    /// Between the screen edge and the buttons, the titles and the page label.
    static let sideMargin: CGFloat = 16
    /// Between the top bar and the text.
    static let textTopGap: CGFloat = 32
    /// Between the text and the bottom bar.
    static let textBottomGap: CGFloat = 16
    /// Space between the screen edge and the text on each side, as a share of the page's width: about 36pt on an iPhone,
    /// 70pt on an iPad in portrait.
    static let textMarginRatio: CGFloat = 0.09
}

/// Where a full-screen page puts its header (the book and chapter titles), its text and its footer (the page label),
/// worked out from the screen alone. In the screen's own coordinates, which a full-screen page shares.
/// Pagination uses `viewport`, so a page holds exactly the text that fits where it is drawn.
struct PageLayout: Equatable, Sendable {
    let header: CGRect
    let text: CGRect
    let footer: CGRect
    let horizontalMargin: CGFloat

    var viewport: Viewport {
        Viewport(size: text.size, horizontalMargin: horizontalMargin)
    }

    init(_ screen: ScreenGeometry) {
        typealias Knobs = PageLayoutKnobs
        let width = screen.size.width
        let barWidth = width - 2 * Knobs.sideMargin
        header = CGRect(x: Knobs.sideMargin, y: screen.safeAreaTop, width: barWidth, height: Knobs.barHeight)
        footer = CGRect(x: Knobs.sideMargin, y: screen.size.height - screen.safeAreaBottom - Knobs.barHeight,
                        width: barWidth, height: Knobs.barHeight)
        let textTop = header.maxY + Knobs.textTopGap
        text = CGRect(x: 0, y: textTop, width: width, height: footer.minY - Knobs.textBottomGap - textTop)
        horizontalMargin = (width * Knobs.textMarginRatio).rounded()
    }
}
