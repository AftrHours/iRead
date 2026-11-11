import SwiftUI

/// The reader's top bar: the back button, and the book title over the chapter title, centred.
struct TopBar: View {
    let title: String
    let chapterTitle: String
    let foreground: Color
    let colorScheme: ColorScheme
    let isFocusMode: Bool
    let onBack: () -> Void
    /// nil hides the debug button (always nil in release builds).
    var onUnderlineDebug: (() -> Void)?

    var body: some View {
        ZStack {
            VStack(spacing: 10) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(chapterTitle)
                    .font(.caption2)
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
            .foregroundStyle(foreground)
//            .padding(.horizontal, 64)
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
}

#Preview("Top Bar") {
    TopBar(
        title: "Little Women",
        chapterTitle: "Chapter 3",
        foreground: .primary,
        colorScheme: .light,
        isFocusMode: false,
        onBack: { print("Back ditekan") }
    )
}

#Preview("Top Bar – Debug Button") {
    TopBar(
        title: "Little Women",
        chapterTitle: "Chapter 3",
        foreground: .primary,
        colorScheme: .light,
        isFocusMode: false,
        onBack: { print("Back ditekan") },
        onUnderlineDebug: { print("Debug ditekan") }
    )
}

#Preview("Top Bar – Focus Mode") {
    TopBar(
        title: "Little Women",
        chapterTitle: "Chapter 3",
        foreground: .primary,
        colorScheme: .light,
        isFocusMode: true,
        onBack: {}
    )
}
