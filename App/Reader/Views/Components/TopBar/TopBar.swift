import SwiftUI

/// The reader's top bar: the back button on the left and, in debug builds, the underline debug button on the right.
/// The book and chapter titles are not part of it: each page draws its own, so they turn with the page.
struct TopBar: View {
    let foreground: Color
    let colorScheme: ColorScheme
    let isFocusMode: Bool
    let onBack: () -> Void
    /// nil hides the debug button (always nil in release builds).
    var onUnderlineDebug: (() -> Void)?

    var body: some View {
        HStack {
            BackButton(
                systemImage: "xmark",
                accessibilityLabel: "Back",
                foreground: foreground,
                colorScheme: colorScheme,
                isVisible: !isFocusMode,
                action: onBack
            )
            Spacer()
            if let onUnderlineDebug {
                BackButton(
                    systemImage: "ladybug",
                    accessibilityLabel: "Underline Debug",
                    foreground: foreground,
                    colorScheme: colorScheme,
                    isVisible: !isFocusMode,
                    action: onUnderlineDebug
                )
                .keyboardShortcut("d", modifiers: [.command, .shift])
            }
        }
    }
}

#Preview("Top Bar") {
    TopBar(
        foreground: .primary,
        colorScheme: .light,
        isFocusMode: false,
        onBack: { print("Back ditekan") }
    )
}

#Preview("Top Bar – Debug Button") {
    TopBar(
        foreground: .primary,
        colorScheme: .light,
        isFocusMode: false,
        onBack: { print("Back ditekan") },
        onUnderlineDebug: { print("Debug ditekan") }
    )
}

#Preview("Top Bar – Focus Mode") {
    TopBar(
        foreground: .primary,
        colorScheme: .light,
        isFocusMode: true,
        onBack: {}
    )
}
