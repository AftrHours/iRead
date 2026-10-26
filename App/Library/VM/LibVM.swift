import Observation
import UIKit

@MainActor
@Observable
final class LibVM {
    struct ShareFile: Identifiable {
        let url: URL
        var id: URL { url }
    }

    enum ViewMode {
        case grid
        case list
    }

    private(set) var allBooks: [BookRecord] = []
    private(set) var viewMode = ViewMode.grid
    private(set) var sortOption = LibrarySortOption.latestRead
    private(set) var importError: String?
    private(set) var covers: [UUID: UIImage] = [:]
    private(set) var bookToRemove: BookRecord?
    private(set) var bookActionError: String?
    private(set) var shareFile: ShareFile?
    private var newestImportedBookID: UUID?

    var books: [BookRecord] {
        LibrarySorter.sorted(allBooks, by: sortOption, pinning: newestImportedBookID)
    }

    private static let coverSize = CGSize(width: 400, height: 600)
    private let libCtrl: LibCtrl
    private let appNav: AppNav

    init(libCtrl: LibCtrl, appNav: AppNav) {
        self.libCtrl = libCtrl
        self.appNav = appNav
    }

    func onAppear() async {
        allBooks = (try? await libCtrl.loadLibrary()) ?? []
        await loadCovers()
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
                await loadCovers()
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

    func finishedToggled(_ book: BookRecord) {
        Task {
            await libCtrl.setFinished(!book.isFinished, for: book)
            await reloadLibrary()
        }
    }

    func resetProgressTapped(_ book: BookRecord) {
        Task {
            await libCtrl.resetProgress(for: book)
            await reloadLibrary()
        }
    }

    func removeTapped(_ book: BookRecord) {
        bookToRemove = book
    }

    func removeCancelled() {
        bookToRemove = nil
    }

    func removeConfirmed() {
        guard let book = bookToRemove else { return }
        bookToRemove = nil
        do {
            try libCtrl.remove(book)
        } catch {
            bookActionError = error.localizedDescription
        }
        Task { await reloadLibrary() }
    }

    func dismissBookActionError() {
        bookActionError = nil
    }

    func shareTapped(_ book: BookRecord) {
        Task {
            do {
                shareFile = ShareFile(url: try await libCtrl.shareableFile(for: book))
            } catch {
                bookActionError = error.localizedDescription
            }
        }
    }

    func shareDismissed() {
        shareFile = nil
    }

    private func reloadLibrary() async {
        allBooks = (try? await libCtrl.loadLibrary()) ?? allBooks
    }

    private func loadCovers() async {
        for book in allBooks where covers[book.id] == nil {
            guard let data = await libCtrl.cover(for: book.id) else { continue }
            // Shrunk once here, so scrolling the grid never decodes a full-size cover.
            covers[book.id] = await UIImage(data: data)?.byPreparingThumbnail(ofSize: Self.coverSize)
        }
    }
}
