import Foundation
import Observation

@MainActor
@Observable
final class LibVM {
    enum ViewMode {
        case grid
        case list
    }

    private(set) var continueBooks: [BookRecord] = []
    private(set) var allBooks: [BookRecord] = []
    private(set) var viewMode = ViewMode.grid

    private let libCtrl: LibCtrl
    private let appNav: AppNav

    init(libCtrl: LibCtrl, appNav: AppNav) {
        self.libCtrl = libCtrl
        self.appNav = appNav
    }

    func onAppear() async {
        let books = (try? await libCtrl.loadLibrary()) ?? []
        continueBooks = books.filter { $0.isContinueReading }
        allBooks = books.filter { !$0.isContinueReading }
    }

    func viewModeChanged(_ viewMode: ViewMode) {
        self.viewMode = viewMode
    }

    func addTapped() {}

    func searchTapped() {}

    func bookTapped(_ book: BookRecord) {
        appNav.openReader(bookID: book.id)
    }
}
