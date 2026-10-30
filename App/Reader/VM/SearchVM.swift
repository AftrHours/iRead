import Foundation
import Observation

@MainActor
@Observable
final class SearchVM {
    private(set) var query = ""
    private(set) var results: [SearchResult] = []
    private(set) var recentSearches: [String] = []

    private let readerCtrl: ReaderCtrl
    private let readerStateCtrl: ReaderStateCtrl
    private let onResultPicked: (SearchResult) -> Void
    private var searchTask: Task<Void, any Error>?

    init(readerCtrl: ReaderCtrl, readerStateCtrl: ReaderStateCtrl, onResultPicked: @escaping (SearchResult) -> Void) {
        self.readerCtrl = readerCtrl
        self.readerStateCtrl = readerStateCtrl
        self.onResultPicked = onResultPicked
        Task { recentSearches = await readerStateCtrl.recentSearches() }
    }

    func queryChanged(_ query: String) {
        self.query = query
        searchTask?.cancel()
        searchTask = Task {
            let results = await readerCtrl.search(query)
            try Task.checkCancellation()
            self.results = results
        }
    }

    func querySubmitted() {
        saveRecentSearch()
    }

    func recentSearchTapped(_ query: String) {
        queryChanged(query)
    }

    func clearRecentSearchesTapped() {
        recentSearches = []
        Task { await readerStateCtrl.clearRecentSearches() }
    }

    func resultTapped(_ result: SearchResult) {
        saveRecentSearch()
        onResultPicked(result)
    }

    private func saveRecentSearch() {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        Task {
            await readerStateCtrl.saveRecentSearch(query)
            recentSearches = await readerStateCtrl.recentSearches()
        }
    }
}
