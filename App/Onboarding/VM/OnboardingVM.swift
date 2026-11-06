import Foundation
import Observation

@MainActor
@Observable
final class OnboardingVM {
    var page = 0
    var isPickingBook = false
    private(set) var importError: String?
    private(set) var shouldFinish = false

    private let importBooks: @MainActor ([URL]) async -> Bool

    var primaryActionTitle: String { page == 0 ? "Next" : "Start Reading" }
    var primaryActionSymbol: String { page == 0 ? "arrow.right" : "book" }
    var pageIndicatorLabel: String { "Page \(page + 1) of 2" }

    var isImportAlertPresented: Bool {
        get { importError != nil }
        set { if !newValue { dismissImportError() } }
    }

    init(importBooks: @escaping @MainActor ([URL]) async -> Bool) {
        self.importBooks = importBooks
    }

    func skipTapped() {
        shouldFinish = true
    }

    func primaryActionTapped() {
        if page == 0 {
            page = 1
        } else {
            shouldFinish = true
        }
    }

    func importTapped() {
        isPickingBook = true
    }

    func importPickerCompleted(_ result: Result<[URL], any Error>) {
        isPickingBook = false
        guard case .success(let urls) = result else {
            if case .failure(let error) = result,
               (error as? CocoaError)?.code != .userCancelled {
                importError = error.localizedDescription
            }
            return
        }

        Task {
            if await importBooks(urls) {
                shouldFinish = true
            } else {
                importError = "We couldn’t add that EPUB. Try another file from the Library."
            }
        }
    }

    func dismissImportError() {
        importError = nil
    }

    func isPageSelected(_ index: Int) -> Bool {
        page == index
    }
}
