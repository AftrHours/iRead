import SwiftUI

extension View {
    /// Only the symbol and its tap target are capped. Menu items and field text inherit the user's full text size.
    func libraryIconFrame(_ diameter: CGFloat = 48, alignment: Alignment = .center, square: Bool = true) -> some View {
        modifier(LibraryIconFrame(diameter: diameter, alignment: alignment, square: square))
            .dynamicTypeSize(...LibraryLayout.maximumIconSize)
    }

    func libraryControlLabel(_ title: LocalizedStringKey, symbol: String) -> some View {
        accessibilityLabel(Text(title))
            .accessibilityShowsLargeContentViewer { Label(title, systemImage: symbol) }
    }
}

private struct LibraryIconFrame: ViewModifier {
    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1
    let diameter: CGFloat
    let alignment: Alignment
    let square: Bool

    func body(content: Content) -> some View {
        let side = max(44, diameter * scale)
        content.frame(width: square ? side : nil, height: side, alignment: alignment)
    }
}
