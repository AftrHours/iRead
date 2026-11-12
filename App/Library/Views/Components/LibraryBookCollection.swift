import SwiftUI

struct LibraryBookCollection: View {
    let items: [LibraryBookItemVM]
    let viewMode: LibVM.ViewMode
    let layout: LibraryLayout
    let onBookTapped: (BookRecord) -> Void
    let onFinished: (BookRecord) -> Void
    let onRename: (BookRecord) -> Void
    let onRemove: (BookRecord) -> Void

    var body: some View {
        ScrollView {
            Group {
                switch viewMode {
                case .grid:
                    LazyVGrid(columns: layout.gridColumns, spacing: layout.gridRowSpacing) {
                        ForEach(items) { item in
                            BookGridView(item: item, menu: bookMenu(for: item))
                                .overlay(alignment: .topTrailing) { LibrarySelectionBadge(item: item) }
                                .contentShape(.rect)
                                .onTapGesture { onBookTapped(item.book) }
                        }
                    }
                case .list:
                    LazyVStack(spacing: 12) {
                        ForEach(items) { item in
                            BookRowView(item: item, menu: bookMenu(for: item))
                                .overlay(alignment: .trailing) { LibrarySelectionBadge(item: item) }
                                .contentShape(.rect)
                                .onTapGesture { onBookTapped(item.book) }
                            Rectangle()
                                .fill(LibraryPalette.divider)
                                .frame(height: 1)
                        }
                    }
                }
            }
            .padding(.horizontal, layout.sideMargin)
            .padding(.bottom, 28)
        }
    }

    private func bookMenu(for item: LibraryBookItemVM) -> BookMenu {
        BookMenu(item: item, onFinished: { onFinished(item.book) },
                 onRename: { onRename(item.book) }, onRemove: { onRemove(item.book) })
    }
}

#Preview("Library Collection") {
    LibView(libVM: PreviewFixtures.libraryVM())
}
