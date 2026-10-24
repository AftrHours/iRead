import Foundation
import Observation

@MainActor
@Observable
final class LibVM {
    enum ViewMode {
        case grid
        case list
    }

    private(set) var allBooks: [BookRecord] = []
    private(set) var viewMode = ViewMode.grid
    private(set) var sortOption = LibrarySortOption.latestRead
    private(set) var importError: String?
    private var newestImportedBookID: UUID?

    var books: [BookRecord] {
        LibrarySorter.sorted(allBooks, by: sortOption, pinning: newestImportedBookID)
    }

    private let libCtrl: LibCtrl
    private let appNav: AppNav

    init(libCtrl: LibCtrl, appNav: AppNav) {
        self.libCtrl = libCtrl
        self.appNav = appNav
    }

    func onAppear() async {
        allBooks = (try? await libCtrl.loadLibrary()) ?? []
    }

    func toggleViewMode() {
        viewMode = viewMode == .grid ? .list : .grid
    }

    func sortChanged(_ sortOption: LibrarySortOption) {
        self.sortOption = sortOption
        newestImportedBookID = nil
    }

    func importFiles(_ result: Result<[URL], any Error>) async {
        switch result {
        case .success(let urls):
            do {
                for url in urls {
                    let importedBook = try await libCtrl.importBook(from: url)
                    newestImportedBookID = importedBook.id
                }
                allBooks = try await libCtrl.loadLibrary()
            } catch {
                allBooks = (try? await libCtrl.loadLibrary()) ?? allBooks
                importError = error.localizedDescription
            }
        case .failure(let error):
            // User cancellation is a normal document picker outcome.
            if (error as? CocoaError)?.code != .userCancelled {
                importError = error.localizedDescription
            }
        }
    }

    func dismissImportError() {
        importError = nil
    }

    func searchTapped() {}

    func bookTapped(_ book: BookRecord) {
        appNav.openReader(book: book)
    }
}
