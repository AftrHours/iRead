import SwiftUI

/// Context actions available for one library book.
struct BookMenu: View {
    let item: LibraryBookItemVM
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
            Group {
                if item.isMenuHidden {
                    Color.clear
                } else {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(AppColors.cardTextSecondary)
                }
            }
            .frame(width: 30, height: 44)
            .contentShape(.rect)
        }
        .tint(.secondary)
        .disabled(item.isMenuHidden)
        .accessibilityLabel(item.menuAccessibilityLabel)
    }
}

#Preview("Book Actions") {
    let book = BookRecord.samples[0].book
    BookMenu(item: LibraryBookItemVM(book: book), onFinished: {}, onRename: {}, onRemove: {})
        .padding()
}
