import SwiftUI

/// Circular library control used by the import, layout, and sort actions. ganti nama jadi AddBook
struct LibraryIconButton: View {
    let systemName: String
    let accessibilityLabel: String
    let fill: Color
    let foreground: Color
    let size: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(AppTypography.callout(.semibold))
                .foregroundStyle(foreground)
                .frame(width: size, height: size)
                .contentShape(.circle)
                .background(fill, in: .circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

#Preview("Library Buttons") {
    HStack(spacing: 16) {
        LibraryIconButton(systemName: "plus", accessibilityLabel: "Add book", fill: LibraryPalette.addButton,
                          foreground: .white, size: 50, action: {})
        LibraryIconButton(systemName: "square.grid.2x2", accessibilityLabel: "Grid view", fill: LibraryPalette.controlFill,
                          foreground: LibraryPalette.primaryText, size: 48, action: {})
    }
    .padding()
    .background(LibraryPalette.page)
}
