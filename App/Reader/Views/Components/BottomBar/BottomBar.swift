import SwiftUI

/// The reader's bottom bar: the page label on the left, Return to Reading (or its toast) in the middle,
/// and the ••• button that opens `menuItems` on the right.
/// Always 44pt tall, so Return appearing never resizes the page and makes the book paginate again.
struct BottomBar<MenuItems: View>: View {
    let pageLabel: String
    let foreground: Color
    let colorScheme: ColorScheme
    let isFocusMode: Bool
    let canReturn: Bool
    let toastText: String?
    let onReturnDismissed: () -> Void
    let onReturnTapped: () -> Void
    @ViewBuilder let menuItems: () -> MenuItems

    var body: some View {
        HStack {
            Text(pageLabel)
                .font(.caption)
                .foregroundStyle(foreground)
            Spacer()
            ToolbarMenu(
                foreground: foreground,
                colorScheme: colorScheme,
                isVisible: !isFocusMode,
                items: menuItems
            )
        }
        .frame(height: 44)
        // An overlay, so it never changes the bar's height. Stays in focus mode: it is the way back.
        .overlay {
            ReturnControls(
                canReturn: canReturn,
                toastText: toastText,
                onDismiss: onReturnDismissed,
                onReturn: onReturnTapped
            )
        }
    }
}

#Preview("Bottom Bar") {
    BottomBar(
        pageLabel: "Page 41 of 684",
        foreground: .primary,
        colorScheme: .light,
        isFocusMode: false,
        canReturn: false,
        toastText: nil,
        onReturnDismissed: {},
        onReturnTapped: {},
        menuItems: {
            Button("Contents", systemImage: "list.bullet") {}
            Button("Search in Book", systemImage: "magnifyingglass") {}
            Button("Theme & Settings", systemImage: "textformat") {}
        }
    )
}

#Preview("Bottom Bar – Return") {
    BottomBar(
        pageLabel: "Page 41 of 684",
        foreground: .primary,
        colorScheme: .light,
        isFocusMode: false,
        canReturn: true,
        toastText: nil,
        onReturnDismissed: {},
        onReturnTapped: {},
        menuItems: { EmptyView() }
    )
}

#Preview("Bottom Bar – Toast") {
    BottomBar(
        pageLabel: "Page 12 of 684",
        foreground: .primary,
        colorScheme: .light,
        isFocusMode: false,
        canReturn: false,
        toastText: "Returned to page 12",
        onReturnDismissed: {},
        onReturnTapped: {},
        menuItems: { EmptyView() }
    )
}

#Preview("Bottom Bar – Focus Mode") {
    BottomBar(
        pageLabel: "Page 41",
        foreground: .primary,
        colorScheme: .light,
        isFocusMode: true,
        canReturn: false,
        toastText: nil,
        onReturnDismissed: {},
        onReturnTapped: {},
        menuItems: { EmptyView() }
    )
}
