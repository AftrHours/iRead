import SwiftUI

struct LibraryBookCollection<Header: View>: View {
    let items: [LibraryBookItemVM]
    let viewMode: LibVM.ViewMode
    let layout: LibraryLayout
    let onBookTapped: (BookRecord) -> Void
    let onFinished: (BookRecord) -> Void
    let onRename: (BookRecord) -> Void
    let onRemove: (BookRecord) -> Void
    var showsLibraryTitle = false
    var resultsTitle: String?
    var onScrolled: ((CGFloat) -> Void)? = nil
    @ViewBuilder let header: () -> Header

    var body: some View {
        scrollingContent
            .scrollEdgeEffectStyle(.soft, for: .top)
    }

    private var scrollingContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header()
                if showsLibraryTitle {
                    LibraryTitleView()
                        .padding(.top, 10)
                        .padding(.bottom, 12)
                }

                if let resultsTitle {
                    Text(resultsTitle)
                        .font(AppTypography.title3(.semibold))
                        .foregroundStyle(AppColors.textPrimary)
                        .padding(.bottom, 16)
                }

                books
            }
            .padding(.horizontal, layout.collectionSideMargin)
            .padding(.bottom, 28)
        }
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top
        } action: { _, offset in
            onScrolled?(offset)
        }
    }

    @ViewBuilder
    private var books: some View {
        switch viewMode {
        case .grid:
            LazyVGrid(columns: layout.gridColumns, spacing: layout.gridRowSpacing) {
                ForEach(items) { item in
                    BookGridView(item: item, menu: bookMenu(for: item, style: .card))
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

    private func bookMenu(for item: LibraryBookItemVM, style: BookMenu.Style = .list) -> BookMenu {
        BookMenu(item: item, style: style, onFinished: { onFinished(item.book) },
                 onRename: { onRename(item.book) }, onRemove: { onRemove(item.book) })
    }
}

#Preview("Library Collection") {
    LibView(libVM: PreviewFixtures.libraryVM())
}
