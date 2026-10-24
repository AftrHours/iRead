import SwiftUI

struct LibView: View {
    var libVM: LibVM
    @State private var isImporting = false

    private let gridColumns = Array(repeating: GridItem(.flexible()), count: 4)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            topBarView
                .padding(.horizontal)
                .padding(.bottom, 24)

            headerView
                .padding(.horizontal)
                .padding(.bottom, 24)

            if libVM.books.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    Group {
                        if libVM.viewMode == .grid {
                            LazyVGrid(columns: gridColumns, spacing: 24) {
                                ForEach(libVM.books) { book in
                                    BookGridView(book: book)
                                        .onTapGesture { libVM.bookTapped(book) }
                                }
                            }
                        } else {
                            LazyVStack(spacing: 16) {
                                ForEach(libVM.books) { book in
                                    BookRowView(book: book)
                                        .onTapGesture { libVM.bookTapped(book) }
                                    Divider()
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
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
    }

    private var topBarView: some View {
        HStack {
            Spacer()
            HStack {
                Image(systemName: "magnifyingglass")
                Text("Search Book")
                    .foregroundColor(.gray)
                Spacer()
                Image(systemName: "mic")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Capsule().stroke(Color.gray.opacity(0.3)))
            .frame(width: 200)
            .onTapGesture { libVM.searchTapped() }

            Button { isImporting = true } label: {
                Image(systemName: "plus")
                    .padding(12)
                    .background(Circle().fill(Color.gray.opacity(0.2)))
                    .foregroundColor(.black)
            }
            .accessibilityLabel("Import EPUB")
        }
    }

    private var headerView: some View {
        HStack {
            Text("Library")
                .font(.largeTitle)
                .fontWeight(.bold)

            Spacer()

            Button { libVM.toggleViewMode() } label: {
                Image(systemName: libVM.viewMode == .grid ? "square.grid.2x2" : "list.bullet")
                    .font(.title3)
                    .frame(width: 44, height: 44)
                    .background(Circle().stroke(Color.gray.opacity(0.25)))
                    .foregroundColor(.black)
            }
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
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.title3)
                    .frame(width: 44, height: 44)
                    .background(Circle().stroke(Color.gray.opacity(0.25)))
                    .foregroundColor(.black)
            }
            .accessibilityLabel("Sort library")
        }
    }

    private var emptyStateView: some View {
        VStack {
            Spacer()
            Text("No books yet")
                .font(.headline)
            Text("Tap the + button to import an EPUB")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview("Library View") {
    LibView(libVM: LibVM(libCtrl: LibCtrl(libRepo: LibRepo(epubParseSvc: EPUBParseSvc(), progRepo: ProgRepo())), appNav: AppNav()))
}
