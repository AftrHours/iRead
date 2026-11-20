import SwiftUI

struct LibraryBookCollection<Header: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let items: [LibraryBookItemVM]
    let viewMode: LibVM.ViewMode
    let layout: LibraryLayout
    let onBookTapped: (BookRecord) -> Void
    let onFinished: (BookRecord) -> Void
    let onRename: (BookRecord) -> Void
    let onRemove: (BookRecord) -> Void
    var showsLibraryTitle = false
    var resultsTitle: String?
    var onScrolled: ((CGFloat) -> Void)?
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
                        .accessibilityAddTraits(.isHeader)
                        .font(AppTypography.title3(.semibold))
                        .foregroundStyle(AppColors.textPrimary)
                        .padding(.bottom, 16)
                }

                books
                    .accessibilityElement(children: .contain)
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
            LazyVGrid(columns: layout.gridColumns(for: dynamicTypeSize), spacing: layout.gridRowSpacing) {
                ForEach(items.enumerated(), id: \.element.id) { index, item in
                    BookGridView(item: item, menu: bookMenu(for: item, style: .card)) {
                        onBookTapped(item.book)
                    }
                    .accessibilityElement(children: .contain)
                    .environment(\.libraryBookMenuPriority, Double(items.count - index) * 2)
                }
            }
        case .list:
            LazyVStack(spacing: 12) {
                ForEach(items.enumerated(), id: \.element.id) { index, item in
                    BookRowView(item: item, menu: bookMenu(for: item)) {
                        onBookTapped(item.book)
                    }
                    .accessibilityElement(children: .contain)
                    .environment(\.libraryBookMenuPriority, Double(items.count - index) * 2)
                    Rectangle()
                        .fill(LibraryPalette.divider)
                        .frame(height: 1)
                        .accessibilityHidden(true)
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
