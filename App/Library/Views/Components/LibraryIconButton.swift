import SwiftUI

/// Circular library control used by the import, layout, and sort actions.
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
                .font(.title3.weight(.medium))
                .foregroundStyle(foreground)
                .frame(width: size, height: size)
                .contentShape(.circle)
                .background(fill, in: .circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}
