import CoreGraphics

/// The page's size, and the room left and right of the text. ReaderView decides both.
struct Viewport: Equatable, Sendable {
    let size: CGSize
    /// Space between the screen edge and the text, on each side. Taps there turn the page.
    var horizontalMargin: CGFloat = 0

    /// Where the text sits in a page: the page minus the margin on each side.
    /// Pagination and drawing both use it, so a page holds exactly the text that fits on screen.
    static func textFrame(in bounds: CGRect, horizontalMargin: CGFloat) -> CGRect {
        bounds.insetBy(dx: min(horizontalMargin, bounds.width / 2), dy: 0)
    }
}
