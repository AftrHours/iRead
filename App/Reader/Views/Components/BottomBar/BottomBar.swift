import SwiftUI

/// The reader's bottom bar: the page label on the left, Stay On This Page and Back to Latest Read (or a toast) in the middle,
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
            // Sits a little above the page label and ••• button. An offset, so the bar's height still doesn't change.
            .offset(y: -24)
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

/// Return showing under the end of a page, with the page label and ••• button, to see how the pills sit above the bar.
#Preview("Bottom Bar – Return on a page", traits: .fixedLayout(width: 834, height: 260)) {
    VStack(spacing: 0) {
        Text("“I’m not! And if turning up my hair makes me one, I’ll wear it in two tails till I’m twenty,” cried Jo, "
             + "pulling off her net, and shaking down a chestnut mane. “I hate to think I’ve got to grow up, and be Miss March, "
             + "and wear long gowns, and look as prim as a China Aster!”")
            .font(.body)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, 32)
            .padding(.top, 24)
        BottomBar(
            pageLabel: "Page 41 of 684",
            foreground: .primary,
            colorScheme: .light,
            isFocusMode: false,
            canReturn: true,
            toastText: nil,
            onReturnDismissed: {},
            onReturnTapped: {},
            menuItems: {
                Button("Contents", systemImage: "list.bullet") {}
                Button("Search in Book", systemImage: "magnifyingglass") {}
                Button("Theme & Settings", systemImage: "textformat") {}
            }
        )
        .padding(.horizontal, 32)
        .padding(.bottom, 16)
    }
    .background(AppColors.readerBackground)
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
