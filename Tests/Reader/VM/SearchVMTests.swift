import Foundation
import Testing
@testable import iRead

/// Stands in for ReaderCtrl.search: records each query and answers with one result whose snippet is the query.
/// A query in `held` waits until `release` is called, even when its search is cancelled.
@MainActor
private final class SearchSpy {
    private(set) var queries: [String] = []
    var held: Set<String> = []
    private var waiting: [String: CheckedContinuation<Void, Never>] = [:]

    func search(_ query: String) async -> [SearchResult] {
        queries.append(query)
        if held.contains(query) {
            await withCheckedContinuation { waiting[query] = $0 }
        }
        return [SearchResult(chapterTitle: "", snippet: query, position: ReadingPosition(paragraph: 0, charOffset: 0), length: 1, pageNumber: 1)]
    }

    func release(_ query: String) {
        waiting.removeValue(forKey: query)?.resume()
    }
}

@Suite("SearchVM", .timeLimit(.minutes(1)))
@MainActor
struct SearchVMTests {
    private let folder = TempFolder()
    private let spy = SearchSpy()

    private func makeSearchVM() -> SearchVM {
        let readerStateCtrl = ReaderStateCtrl(bookID: sampleID, readingSettingsRepo: ReadingSettingsRepo(folder: folder.url),
                                              brightnessSvc: BrightnessSvc(), bookStateRepo: BookStateRepo(folder: folder.url))
        return SearchVM(search: { [spy] in await spy.search($0) }, readerStateCtrl: readerStateCtrl, onResultPicked: { _ in })
    }

    @Test("RD-26 a query shorter than 2 characters clears the results and doesn't search")
    func shortQuery() async throws {
        let searchVM = makeSearchVM()
        searchVM.recentSearchTapped("Anna")
        #expect(await eventually { searchVM.results.map(\.snippet) == ["Anna"] })

        searchVM.queryChanged(" A ")
        #expect(searchVM.results.isEmpty)
        try await Task.sleep(for: SearchVMKnobs.typingPause * 2)
        #expect(spy.queries == ["Anna"])
        #expect(searchVM.results.isEmpty)
    }

    @Test("RD-27 typing several characters quickly runs one search, once typing pauses")
    func typingRunsOneSearch() async throws {
        let searchVM = makeSearchVM()
        for typed in ["A", "An", "Ann", "Anna"] {
            searchVM.queryChanged(typed)
        }
        #expect(spy.queries.isEmpty)
        #expect(await eventually { searchVM.results.map(\.snippet) == ["Anna"] })
        try await Task.sleep(for: SearchVMKnobs.typingPause * 2)
        #expect(spy.queries == ["Anna"])
    }

    @Test("RD-28 a search cancelled by a newer one doesn't overwrite the newer results")
    func cancelledSearchKeepsNewerResults() async throws {
        let searchVM = makeSearchVM()
        spy.held = ["Anna"]
        searchVM.recentSearchTapped("Anna")
        #expect(await eventually { spy.queries == ["Anna"] })

        searchVM.recentSearchTapped("Darcy")
        #expect(await eventually { searchVM.results.map(\.snippet) == ["Darcy"] })
        spy.release("Anna")
        try await Task.sleep(for: .milliseconds(200))
        #expect(searchVM.results.map(\.snippet) == ["Darcy"])
    }
}
