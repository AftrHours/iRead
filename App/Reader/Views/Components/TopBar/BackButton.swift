import SwiftUI

/// Reusable glass action button for the reading controls.
struct BackButton: View {
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
           
                .environment(\.colorScheme, colorScheme)
        }
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel(accessibilityLabel)
        // Hidden in focus mode: invisible, and taps go through to the page instead.
        .opacity(isVisible ? 1 : 0)
        .allowsHitTesting(isVisible)
        .accessibilityHidden(!isVisible)
    }
}

#Preview("Tap Area") {
    @Previewable @State var taps = 0
    VStack(spacing: 24) {
        BackButton(
            systemImage: "chevron.left",
            accessibilityLabel: "Back",
            foreground: .primary,
            colorScheme: .light,
            isVisible: true,
            action: { taps += 1 }
        )
        .border(.red)              // garis kotak 44×44

        Text("Ditekan: \(taps)x")
    }
}
