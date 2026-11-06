import SwiftUI

struct LibView: View {
    @Bindable var libVM: LibVM

    // Keep the requested column count stable across orientation and size changes.
    private var gridColumns: [GridItem] {
        let columnCount = UIDevice.current.userInterfaceIdiom == .pad ? 3 : 2
        return Array(repeating: GridItem(.flexible(), spacing: 16, alignment: .top), count: columnCount)
    }
    private static let sideMargin: CGFloat = 28

    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 0) {
                topBarView(searchWidth: min(205, max(0, geometry.size.width - 64 - 50 - 11)))
                    .padding(.horizontal, 32)
                    .padding(.top, 8)

                headerView
                    .padding(.horizontal, Self.sideMargin)
                    .padding(.top, 38)
                    .padding(.bottom, 24)

                if libVM.visibleBooks.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        Group {
                            if libVM.viewMode == .grid {
                                LazyVGrid(columns: gridColumns, spacing: 24) {
                                    ForEach(libVM.visibleBooks) { book in
                                        BookGridView(book: book, cover: libVM.covers[book.id], menu: BookMenu(book: book, libVM: libVM))
                                            .contentShape(.rect)
                                            .onTapGesture { libVM.bookTapped(book) }
                                    }
                                }
                            } else {
                                LazyVStack(spacing: 16) {
                                    ForEach(libVM.visibleBooks) { book in
                                        BookRowView(book: book, cover: libVM.covers[book.id], menu: BookMenu(book: book, libVM: libVM))
                                            .contentShape(.rect)
                                            .onTapGesture { libVM.bookTapped(book) }
                                        Rectangle()
                                            .fill(LibraryPalette.divider)
                                            .frame(height: 1)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, Self.sideMargin)
                        .padding(.bottom, 28)
                    }
                }
            }
        }
        .task { await libVM.onAppear() }
        .background(LibraryPalette.page.ignoresSafeArea())
        .background {
            EPUBDocumentPicker(isPresented: $libVM.isImportPickerPresented) { result in
                libVM.importPickerCompleted(result)
            }
        }
        .alert("Couldn’t import EPUB", isPresented: $libVM.isImportAlertPresented) {
            Button("OK", role: .cancel) { libVM.dismissImportError() }
        } message: {
            Text(libVM.importError ?? "Please try another EPUB file.")
        }
        .alert("Remove Book?", isPresented: $libVM.isRemoveAlertPresented, presenting: libVM.bookToRemove) { _ in
            Button("Remove", role: .destructive) { libVM.removeConfirmed() }
            Button("Cancel", role: .cancel) { libVM.removeCancelled() }
        } message: { book in
            Text("“\(book.title)” and your reading progress will be removed from this iPad.")
        }
        .alert("Something went wrong", isPresented: $libVM.isBookActionAlertPresented) {
            Button("OK", role: .cancel) { libVM.dismissBookActionError() }
        } message: {
            Text(libVM.bookActionError ?? "")
        }
    }

    private func topBarView(searchWidth: CGFloat) -> some View {
        HStack(spacing: 11) {
            Spacer()
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(LibraryPalette.primaryText)
                TextField("Search Book", text: $libVM.searchText)
                    .foregroundStyle(LibraryPalette.primaryText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                Spacer(minLength: 0)
                Image(systemName: "mic")
                    .foregroundStyle(LibraryPalette.secondaryText)
            }
            .padding(.horizontal, 14)
            .frame(width: searchWidth, height: 46)
            .contentShape(.capsule)
            .background(LibraryPalette.searchFill, in: .capsule)
            .overlay(Capsule().stroke(LibraryPalette.divider.opacity(0.55), lineWidth: 1))

            LibraryIconButton(
                systemName: "plus",
                accessibilityLabel: "Import EPUB",
                fill: LibraryPalette.addButton,
                foreground: .white,
                size: 50,
                action: libVM.importTapped
            )
        }
    }

    private var headerView: some View {
        HStack(spacing: 11) {
            Text("Library")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(LibraryPalette.primaryText)

            Spacer()

            LibraryIconButton(
                systemName: libVM.viewMode == .grid ? "square.grid.2x2" : "list.bullet",
                accessibilityLabel: libVM.viewMode == .grid ? "Switch to list view" : "Switch to grid view",
                fill: LibraryPalette.controlFill,
                foreground: LibraryPalette.primaryText,
                size: 48,
                action: libVM.toggleViewMode
            )

            LibrarySortMenu(libVM: libVM)
        }
    }

    private var emptyStateView: some View {
        VStack {
            Spacer()
            Text(libVM.emptyStateTitle)
                .font(.headline)
                .foregroundStyle(LibraryPalette.primaryText)
            Text(libVM.emptyStateMessage)
                .font(.subheadline)
                .foregroundStyle(LibraryPalette.secondaryText)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview("Library View") {
    let epubParseSvc = EPUBParseSvcEPUBKit()
    let libCtrl = LibCtrl(
        libRepo: LibRepo(epubParseSvc: epubParseSvc),
        bookContentRepo: BookContentRepo(epubParseSvc: epubParseSvc),
        progRepo: ProgRepo()
    )
    return LibView(libVM: LibVM(libCtrl: libCtrl, appNav: AppNav()))
}
