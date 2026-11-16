import CoreGraphics

/// The screen as the reader sees it: the area inside the safe area, and the room the system keeps at the top and bottom.
/// A view laid out normally reports exactly this. (A view that ignores the safe area sees no insets, so it can't be asked.)
struct ScreenGeometry: Equatable, Sendable {
    var safeSize: CGSize
    var safeAreaTop: CGFloat
    var safeAreaBottom: CGFloat

    /// The whole screen, with the safe area. Only the top and bottom have insets: the app is for an iPhone in portrait and an iPad.
    var size: CGSize {
        CGSize(width: safeSize.width, height: safeSize.height + safeAreaTop + safeAreaBottom)
    }
}
