import SwiftUI

/// The reader's bottom bar: the ••• button on the right, that opens `menuItems`.
/// As tall as `PageLayoutKnobs.barHeight`, which is where the page label drawn on each page is centred.
/// The page label is not part of it: each page draws its own, so it turns with the page.
/// The return pills and toast are not part of it either: `ReaderView` centres them on the screen above it.
struct BottomBar<MenuItems: View>: View {
    let foreground: Color
    let colorScheme: ColorScheme
    let isFocusMode: Bool
    @ViewBuilder let menuItems: () -> MenuItems

    var body: some View {
        HStack {
            Spacer()
            ToolbarMenu(
                foreground: foreground,
                colorScheme: colorScheme,
                isVisible: !isFocusMode,
                items: menuItems
            )
        }
        .frame(height: PageLayoutKnobs.barHeight)
    }
}

#Preview("Bottom Bar") {
    BottomBar(
        foreground: .primary,
        colorScheme: .light,
        isFocusMode: false,
        menuItems: {
            Button("Contents", systemImage: "list.bullet") {}
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
        menuItems: { EmptyView() }
    )
}
