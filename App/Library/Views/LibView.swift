import SwiftUI

struct LibView: View {
    var libVM: LibVM
    @State private var isImporting = false

    // Sizes and gaps from the library design (iPad 11").
    // As many columns as fit: 4 in portrait like the design, 6 in landscape, so covers keep the same size.
    private let gridColumns = [GridItem(.adaptive(minimum: 160), spacing: 26, alignment: .top)]
    private static let sideMargin: CGFloat = 35

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            topBarView
                .padding(.horizontal, 32)
                .padding(.top, 8)

            headerView
                .padding(.horizontal, Self.sideMargin)
                .padding(.top, 44)
                .padding(.bottom, 30)

            if libVM.books.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    Group {
                        if libVM.viewMode == .grid {
                            LazyVGrid(columns: gridColumns, spacing: 34) {
                                ForEach(libVM.books) { book in
                                    BookGridView(book: book, cover: libVM.covers[book.id], menu: BookMenu(book: book, libVM: libVM))
                                        .contentShape(.rect)
                                        .onTapGesture { libVM.bookTapped(book) }
                                }
                            }
                        } else {
                            LazyVStack(spacing: 16) {
                                ForEach(libVM.books) { book in
                                    BookRowView(book: book, cover: libVM.covers[book.id], menu: BookMenu(book: book, libVM: libVM))
                                        .contentShape(.rect)
                                        .onTapGesture { libVM.bookTapped(book) }
                                    Divider()
                                }
                            }
                        }
                    }
                    .padding(.horizontal, Self.sideMargin)
                    .padding(.bottom, 24)
                }
            }
        }
        .task { await libVM.onAppear() }
        .background {
            EPUBDocumentPicker(isPresented: $isImporting) { result in
                Task { await libVM.importFiles(result) }
            }
        }
        .alert("Couldn’t import EPUB", isPresented: Binding(
            get: { libVM.importError != nil },
            set: { if !$0 { libVM.dismissImportError() } }
        )) {
            Button("OK", role: .cancel) { libVM.dismissImportError() }
        } message: {
            Text(libVM.importError ?? "Please try another EPUB file.")
        }
        .sheet(item: Binding(get: { libVM.shareFile }, set: { _ in libVM.shareDismissed() })) { file in
            ShareSheet(url: file.url)
                .presentationDetents([.medium, .large])
        }
        .alert("Remove Book?", isPresented: Binding(
            get: { libVM.bookToRemove != nil },
            set: { if !$0 { libVM.removeCancelled() } }
        ), presenting: libVM.bookToRemove) { _ in
            Button("Remove", role: .destructive) { libVM.removeConfirmed() }
            Button("Cancel", role: .cancel) { libVM.removeCancelled() }
        } message: { book in
            Text("“\(book.title)” and your reading progress will be removed from this iPad.")
        }
        .alert("Something went wrong", isPresented: Binding(
            get: { libVM.bookActionError != nil },
            set: { if !$0 { libVM.dismissBookActionError() } }
        )) {
            Button("OK", role: .cancel) { libVM.dismissBookActionError() }
        } message: {
            Text(libVM.bookActionError ?? "")
        }
    }

    private var topBarView: some View {
        HStack(spacing: 11) {
            Spacer()
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                Text("Search Book")
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Image(systemName: "mic")
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .frame(width: 195, height: 46)
            .contentShape(.capsule)
            .glassEffect(.regular.interactive(), in: .capsule)
            .onTapGesture { libVM.searchTapped() }

            Button { isImporting = true } label: {
                circleIcon("plus", size: 50)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Import EPUB")
        }
    }

    private var headerView: some View {
        HStack(spacing: 11) {
            Text("Library")
                .font(.largeTitle)
                .fontWeight(.bold)

            Spacer()

            Button { libVM.toggleViewMode() } label: {
                circleIcon(libVM.viewMode == .grid ? "square.grid.2x2" : "list.bullet", size: 48)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(libVM.viewMode == .grid ? "Switch to list view" : "Switch to grid view")

            Menu {
                Picker("Sort by", selection: Binding(
                    get: { libVM.sortOption },
                    set: { libVM.sortChanged($0) }
                )) {
                    ForEach(LibrarySortOption.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
            } label: {
                circleIcon("line.3.horizontal.decrease", size: 48)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Sort library")
        }
    }

    /// A glass circle button icon that follows light and dark mode.
    private func circleIcon(_ systemName: String, size: CGFloat) -> some View {
        Image(systemName: systemName)
            .font(.title3)
            .foregroundStyle(.primary)
            .frame(width: size, height: size)
            .contentShape(.circle)
            .glassEffect(.regular.interactive(), in: .circle)
    }

    private var emptyStateView: some View {
        VStack {
            Spacer()
            Text("No books yet")
                .font(.headline)
            Text("Tap the + button to import an EPUB")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

/// The "…" menu on a book in the library, with the Apple Books items that fit iRead.
struct BookMenu: View {
    let book: BookRecord
    let libVM: LibVM

    var body: some View {
        Menu {
            Button("Share Book", systemImage: "square.and.arrow.up") {
                libVM.shareTapped(book)
            }
            Button(
                book.isFinished ? "Mark as Still Reading" : "Mark as Finished",
                systemImage: book.isFinished ? "book" : "checkmark.circle"
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
                // Narrower than 44 pt so the title keeps more room; still 44 pt tall.
                .frame(width: 30, height: 44)
                .contentShape(.rect)
        }
        .tint(.secondary)
        .accessibilityLabel("More options for \(book.title)")
    }
}

/// The iOS share sheet for one file.
private struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

#Preview("Library View") {
    let epubParseSvc = EPUBParseSvc()
    let libCtrl = LibCtrl(
        libRepo: LibRepo(epubParseSvc: epubParseSvc, progRepo: ProgRepo()),
        bookContentRepo: BookContentRepo(epubParseSvc: epubParseSvc)
    )
    return LibView(libVM: LibVM(libCtrl: libCtrl, appNav: AppNav()))
}
