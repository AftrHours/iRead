import Observation
import UIKit

@MainActor
@Observable
final class OnboardingVM {
    let library: LibVM
    var page = 0
    var isPickingBook = false
    private(set) var isImporting = false
    private(set) var importedBook: BookRecord?
    var importError: String?

    init(library: LibVM) {
        self.library = library
    }

    var samples: [BookRecord] {
        let order = [45, 2701, 1661, 1342, 514]
        return order.compactMap { number in BookRecord.samples.first { $0.book.gutenbergNumber == number }?.book }
    }

    func importTapped() {
        guard !isImporting else { return }
        library.pickerStarted(source: "onboarding")
        isPickingBook = true
    }

    func importPickerCancelled() {
        library.pickerFailed(CocoaError(.userCancelled))
    }

    func importPickerCompleted(_ result: Result<[URL], any Error>) {
        guard case .success(let urls) = result else {
            if case .failure(let error) = result {
                library.pickerFailed(error)
                if (error as? CocoaError)?.code != .userCancelled { importError = error.localizedDescription }
            }
            return
        }
        guard !urls.isEmpty, !isImporting else { return }
        isImporting = true
        Task {
            defer { isImporting = false }
            let succeeded = await library.importFiles(.success(urls))
            if let message = library.importError {
                importError = message
                library.dismissImportError()
            } else if succeeded, let book = library.allBooks.first(where: { $0.id == library.newestImportedBookID }) {
                importedBook = book
                page = 1
            } else {
                importError = "Please try another EPUB."
            }
        }
    }
}

extension OnboardingVM {
    func heading(for page: Int) -> String {
        switch page {
        case 0: "Bring your first\nstory along!"
        case 1: importedBook == nil ? "No book yet?\nNo worries!" : "Your first story\nis ready!"
        case 2: "Revisit an earlier\npassage"
        default: "You’re all set!"
        }
    }

    func subtitle(for page: Int) -> String {
        switch page {
        case 0: "Tap + to choose an EPUB\nfrom Files."
        case 1: importedBook == nil ? "We’ve added a few books to\nyour Library, you can add your\nown anytime." : "Tap + to choose an EPUB\nfrom Files."
        case 2: "Tap an underlined phrase to\nrevisit the author’s earlier words."
        default: "Your Library is ready.\nLet’s head over!"
        }
    }
}
