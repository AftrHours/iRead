import SwiftUI

/// Context actions available for one library book.
struct BookMenu: View {
    let book: BookRecord
    let libVM: LibVM

    var body: some View {
        Menu {
            Button("Share Book", systemImage: "square.and.arrow.up") {
                libVM.shareTapped(book)
            }
            Button(
                libVM.finishedActionTitle(for: book),
                systemImage: libVM.finishedActionSymbol(for: book)
            ) {
                libVM.finishedToggled(book)
            }
            Button("Reset Progress", systemImage: "arrow.counterclockwise") {
                libVM.resetProgressTapped(book)
            }
            Divider()
            Button("Remove", systemImage: "trash", role: .destructive) {
                libVM.removeTapped(book)
            }
        } label: {
            Image(systemName: "ellipsis")
                .foregroundStyle(LibraryPalette.secondaryText)
                .frame(width: 30, height: 44)
                .contentShape(.rect)
        }
        .tint(.secondary)
        .accessibilityLabel("More options for \(book.title)")
    }
}
