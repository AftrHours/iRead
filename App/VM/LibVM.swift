import Foundation
import Observation

@MainActor
@Observable
final class LibVM {
    enum ViewMode {
        case grid
        case list
    }

    enum SortOption: String, CaseIterable, Identifiable {
        case title
        case author
        case dateAdded
        case latestRead
        case readProgress

        var id: String { rawValue }
        var title: String {
            switch self {
            case .title: "Title"
            case .author: "Author"
            case .dateAdded: "Date Added"
            case .latestRead: "Latest Read"
            case .readProgress: "Read Progress"
            }
        }
    }

    private(set) var allBooks: [BookRecord] = []
    private(set) var viewMode = ViewMode.grid
    private(set) var sortOption = SortOption.latestRead
    private(set) var importError: String?
    private var newestImportedBookID: UUID?

    var books: [BookRecord] {
        allBooks.sorted { lhs, rhs in
            if lhs.id == newestImportedBookID { return true }
            if rhs.id == newestImportedBookID { return false }
            switch sortOption {
            case .title:
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            case .author:
                return lhs.author.localizedCaseInsensitiveCompare(rhs.author) == .orderedAscending
            case .dateAdded:
                return lhs.dateAdded > rhs.dateAdded
            case .latestRead:
                return (lhs.lastReadAt ?? .distantPast) > (rhs.lastReadAt ?? .distantPast)
            case .readProgress:
                return lhs.progress > rhs.progress
            }
        }
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

    func viewModeChanged(_ viewMode: ViewMode) {
        self.viewMode = viewMode
    }

    func toggleViewMode() {
        viewMode = viewMode == .grid ? .list : .grid
    }

    func sortChanged(_ sortOption: SortOption) {
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
        appNav.openReader(bookID: book.id)
    }
}
