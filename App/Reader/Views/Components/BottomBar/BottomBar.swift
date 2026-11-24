import SwiftUI

/// The return button and the ••• menu. The progress bar and page label are drawn on each page, so they turn with it.
struct BottomBar<MenuItems: View>: View {
    let foreground: Color
    let colorScheme: ColorScheme
    let isFocusMode: Bool
    let canReturn: Bool
    let onReturn: () -> Void
    @ViewBuilder let menuItems: () -> MenuItems

    var body: some View {
        HStack {
            BackButton(
                systemImage: "arrow.uturn.backward",
                accessibilityLabel: "Back to Latest Read",
                foreground: foreground,
                colorScheme: colorScheme,
                isVisible: !isFocusMode || canReturn,
                isEnabled: canReturn,
                action: onReturn
            )
            Spacer()
            ToolbarMenu(
                foreground: foreground,
                colorScheme: colorScheme,
                isVisible: !isFocusMode,
                items: menuItems
            )
        }
        .frame(minHeight: PageLayoutKnobs.barHeight)
    }
}

#Preview("Bottom Bar") {
    BottomBar(
        foreground: .primary,
        colorScheme: .light,
        isFocusMode: false,
        canReturn: false,
        onReturn: {},
        menuItems: {
            Button("Contents", systemImage: "list.bullet") {}
            Button("Characters", systemImage: "person.2") {}
            Button("Search in Book", systemImage: "magnifyingglass") {}
            Button("Theme & Settings", systemImage: "textformat") {}
        }
    )
}

#Preview("Bottom Bar – Focus Mode") {
    BottomBar(
        foreground: .primary,
        colorScheme: .light,
        isFocusMode: true,
        canReturn: true,
        onReturn: {},
        menuItems: { EmptyView() }
    )
}
