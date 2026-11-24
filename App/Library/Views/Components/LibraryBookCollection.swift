import SwiftUI

struct LibraryBookCollection<Header: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.libraryImportDestination) private var destination
    let items: [LibraryBookItemVM]
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
        ScrollViewReader { reader in
            scrollingContent
                .scrollEdgeEffectStyle(.soft, for: .top)
                .task(id: destination) {
                    guard let destination else { return }
                    if items.first?.id == destination {
                        reader.scrollTo("libraryTop", anchor: .top)
                    } else {
                        reader.scrollTo(destination, anchor: .center)
                    }
                }
        }
    }

    private var scrollingContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header()
                    .padding(.horizontal, layout.sideMargin)
                if showsLibraryTitle {
                    LibraryTitleView()
                        .padding(.horizontal, layout.sideMargin)
                        .padding(.top, 10)
                        .padding(.bottom, 12)
                }

                if let resultsTitle {
                    Text(resultsTitle)
                        .padding(.horizontal, layout.sideMargin)
                        .accessibilityAddTraits(.isHeader)
                        .font(AppTypography.title2(.bold))
                        .foregroundStyle(AppColors.textPrimary)
                        .padding(.bottom, 16)
                }

                books
                    .environment(\.isBrowsingLibraryOnPhone, layout.isBrowsingOnPhone)
                    .environment(\.isSelectingLibraryOnPhone, layout.isSelectingOnPhone)
                    .padding(.horizontal, layout.collectionSideMargin)
                    .accessibilityElement(children: .contain)
            }
            .padding(.bottom, 28)
            .id("libraryTop")
        }
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top
        } action: { _, offset in
            onScrolled?(offset)
        }
    }

    @ViewBuilder
    private var books: some View {
        switch layout.viewMode {
        case .grid:
            LazyVGrid(columns: layout.gridColumns(for: dynamicTypeSize), spacing: layout.rowSpacing) {
                ForEach(items.enumerated(), id: \.element.id) { index, item in
                    BookGridView(item: item, isSearchResult: layout.isSearching, menu: bookMenu(for: item, style: .card)) {
                        onBookTapped(item.book)
                    }
                    .accessibilityElement(children: .contain)
                    .environment(\.libraryBookMenuPriority, Double(items.count - index) * 2)
                    .id(item.id)
                }
            }
        case .list:
            LazyVStack(spacing: layout.usesPhoneListSpacing ? 0 : layout.rowSpacing) {
                ForEach(items.enumerated(), id: \.element.id) { index, item in
                    BookRowView(item: item, menu: bookMenu(for: item)) {
                        onBookTapped(item.book)
                    }
                    .accessibilityElement(children: .contain)
                    .environment(\.libraryBookMenuPriority, Double(items.count - index) * 2)
                    .id(item.id)
                    Rectangle()
                        .fill(AppColors.libraryListDivider)
                        .frame(height: 1)
                        .padding(.top, layout.usesPhoneListSpacing ? 15 : 0)
                        .padding(.bottom, layout.usesPhoneListSpacing ? 16 : 0)
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
