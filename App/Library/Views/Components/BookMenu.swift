import SwiftUI

/// Context actions available for one library book.
struct BookMenu: View {
    let book: BookRecord
    let libVM: LibVM
    var isHidden = false

    var body: some View {
        Menu {
            Button(
                libVM.finishedActionTitle(for: book),
                systemImage: libVM.finishedActionSymbol(for: book)
            ) {
                libVM.finishedToggled(book)
            }
            Button("Rename…", systemImage: "textformat") {
                libVM.renameTapped(book)
            }
            Divider()
            Button("Remove…", systemImage: "trash", role: .destructive) {
                libVM.removeTapped(book)
            }
        } label: {
            Group {
                if isHidden {
                    Color.clear
                } else {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(LibraryPalette.secondaryText)
                }
            }
            .frame(width: 30, height: 44)
            .contentShape(.rect)
        }
        .tint(.secondary)
        .disabled(isHidden)
        .accessibilityLabel("More options for \(book.title)")
    }
}

#Preview("Book Actions") {
    let book = BookRecord.samples[0].book
    BookMenu(book: book, libVM: PreviewFixtures.libraryVM())
        .padding()
}
