import SwiftUI

/// Context actions available for one library book.
struct BookMenu: View {
    enum Style {
        case card
        case list

        var iconColor: Color { self == .card ? AppColors.cardMenuIcon : AppColors.cardTextSecondary }
        var iconAlignment: Alignment { self == .card ? .trailing : .center }
    }

    @Environment(\.libraryBookMenuPriority) private var menuPriority
    let item: LibraryBookItemVM
    var style: Style = .list
    let onFinished: () -> Void
    let onRename: () -> Void
    let onRemove: () -> Void

    var body: some View {
        Menu {
            Button(
                item.finishedActionTitle,
                systemImage: item.finishedActionSymbol,
                action: onFinished
            )
            Button("Rename…", systemImage: "textformat", action: onRename)
            Divider()
            Button("Remove…", systemImage: "trash", role: .destructive, action: onRemove)
        } label: {
            Image(systemName: "ellipsis")
                .font(.body)
                .foregroundStyle(style.iconColor)
                .libraryIconFrame(44, alignment: style.iconAlignment)
                .contentShape(.rect)
        }
        .tint(.secondary)
        .accessibilityLabel(item.menuAccessibilityLabel)
        .accessibilitySortPriority(menuPriority)
        .accessibilityShowsLargeContentViewer { Label(item.menuAccessibilityLabel, systemImage: "ellipsis") }
    }
}

#Preview("Book Actions") {
    let book = BookRecord.samples[0].book
    BookMenu(item: LibraryBookItemVM(book: book), style: .card, onFinished: {}, onRename: {}, onRemove: {})
        .padding()
}
