import SwiftUI

/// Reusable glass action button for the reading controls.
struct ReaderCircleButton: View {
    let systemImage: String
    let accessibilityLabel: String
    let foreground: Color
    let colorScheme: ColorScheme
    let isVisible: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title3.weight(.medium))
                .foregroundStyle(foreground)
                .frame(width: 44, height: 44)
                .contentShape(.circle)
                .glassEffect(.regular.interactive(), in: .circle)
                .environment(\.colorScheme, colorScheme)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .opacity(isVisible ? 1 : 0)
        .allowsHitTesting(isVisible)
        .accessibilityHidden(!isVisible)
    }
}
