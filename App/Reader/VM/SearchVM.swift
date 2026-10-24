import Foundation
import Observation

@MainActor
@Observable
final class SearchVM {
    private(set) var query = ""
    private(set) var results: [SearchResult] = []

    private let readerCtrl: ReaderCtrl
    private let onResultPicked: (SearchResult) -> Void
    private var searchTask: Task<Void, any Error>?

    init(readerCtrl: ReaderCtrl, onResultPicked: @escaping (SearchResult) -> Void) {
        self.readerCtrl = readerCtrl
        self.onResultPicked = onResultPicked
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

    func resultTapped(_ result: SearchResult) {
        onResultPicked(result)
    }
}
