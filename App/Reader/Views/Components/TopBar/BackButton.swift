import SwiftUI

extension View {
    func readerIconFrame(_ base: CGFloat = PageLayoutKnobs.barHeight) -> some View {
        modifier(ReaderIconFrame(base: base))
    }
}

private struct ReaderIconFrame: ViewModifier {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let base: CGFloat

    func body(content: Content) -> some View {
        let side = PageLayoutKnobs.controlSize(base, at: dynamicTypeSize)
        content
            .dynamicTypeSize(...PageLayoutKnobs.maximumIconSize)
            .frame(width: side, height: side)
    }
}

/// Reusable glass action button for the reading controls.
struct BackButton: View {
    let systemImage: String
    let accessibilityLabel: String
    let foreground: Color
    let colorScheme: ColorScheme
    let isVisible: Bool
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title3.weight(.medium))
                .foregroundStyle(foreground.opacity(isEnabled ? 1 : 0.3))
                .readerIconFrame()
                .environment(\.colorScheme, colorScheme)
        }
        .glassEffect(.regular.interactive(), in: .circle)
        .disabled(!isEnabled)
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
