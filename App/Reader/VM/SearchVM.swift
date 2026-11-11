import Foundation
import Observation

enum SearchVMKnobs {
    /// How long typing must pause before the book is searched.
    static let typingPause: Duration = .milliseconds(300)
    /// Shorter queries clear the results instead of searching.
    static let minimumQueryLength = 2
}

@MainActor
@Observable
final class SearchVM {
    private(set) var query = ""
    private(set) var results: [SearchResult] = []
    private(set) var recentSearches: [String] = []

    /// `ReaderCtrl.search` in the app; a closure so tests can count searches.
    private let search: (String) async -> [SearchResult]
    private let readerStateCtrl: ReaderStateCtrl
    private let onResultPicked: (SearchResult) -> Void
    private var searchTask: Task<Void, any Error>?

    init(search: @escaping (String) async -> [SearchResult], readerStateCtrl: ReaderStateCtrl,
         onResultPicked: @escaping (SearchResult) -> Void) {
        self.search = search
        self.readerStateCtrl = readerStateCtrl
        self.onResultPicked = onResultPicked
        Task { recentSearches = await readerStateCtrl.recentSearches() }
    }

    init(previewQuery: String? = nil) {
        let folder = URL.temporaryDirectory.appending(path: "iRead-XcodePreview-\(UUID().uuidString)")
        let stateCtrl = ReaderStateCtrl(
            bookID: UUID(),
            readingSettingsRepo: ReadingSettingsRepo(folder: folder),
            brightnessSvc: BrightnessSvc(),
            bookStateRepo: BookStateRepo(folder: folder)
        )
        search = { _ in [] }
        readerStateCtrl = stateCtrl
        onResultPicked = { _ in }
        query = previewQuery ?? ""
        recentSearches = ["Elizabeth", "the old house", "carriage"]
        if previewQuery != nil {
            results = [
                SearchResult(
                    chapterTitle: "A Strange Visitor",
                    snippet: "...the carriage had stopped before the old house, and Elizabeth turned toward the sound...",
                    position: ReadingPosition(paragraph: 3, charOffset: 0),
                    length: 7,
                    pageNumber: 12
                ),
                SearchResult(
                    chapterTitle: "The Journey Begins",
                    snippet: "...she remembered the old house at the edge of the village...",
                    position: ReadingPosition(paragraph: 18, charOffset: 24),
                    length: 7,
                    pageNumber: 34
                )
            ]
        }
    }

    /// Searches once typing pauses, so typing a name runs one search, not one per letter.
    func queryChanged(_ query: String) {
        self.query = query
        startSearch(after: SearchVMKnobs.typingPause)
    }

    func querySubmitted() {
        startSearch(after: .zero)
        saveRecentSearch()
    }

    func recentSearchTapped(_ query: String) {
        self.query = query
        startSearch(after: .zero)
    }

    func clearRecentSearchesTapped() {
        recentSearches = []
        Task { await readerStateCtrl.clearRecentSearches() }
    }

    func resultTapped(_ result: SearchResult) {
        saveRecentSearch()
        onResultPicked(result)
    }

    private func startSearch(after pause: Duration) {
        searchTask?.cancel()
        guard query.trimmingCharacters(in: .whitespacesAndNewlines).count >= SearchVMKnobs.minimumQueryLength else {
            searchTask = nil
            results = []
            return
        }
        let query = query
        searchTask = Task {
            if pause > .zero { try await Task.sleep(for: pause) }
            let results = await search(query)
            // A newer query cancelled this search, so its results are out of date.
            try Task.checkCancellation()
            self.results = results
        }
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
