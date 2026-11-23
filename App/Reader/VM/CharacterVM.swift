import Foundation
import Observation

@MainActor
@Observable
final class CharacterVM {
    private(set) var characters: [BookCharacter] = []
    private(set) var hasLoaded = false
    private(set) var openedID: String?
    private(set) var query = ""
    private(set) var recentSearches: [String] = []

    @ObservationIgnored var onJump: (_ underlineID: String) -> Void = { _ in }

    private let characterCtrl: CharacterCtrl
    private let readerStateCtrl: ReaderStateCtrl
    private var loadTask: Task<Void, Never>?

    init(characterCtrl: CharacterCtrl, readerStateCtrl: ReaderStateCtrl) {
        self.characterCtrl = characterCtrl
        self.readerStateCtrl = readerStateCtrl
    }

    var shownCharacters: [BookCharacter] {
        characters.filter { CharacterRules.matches($0, query: query) }
    }

    var showsEmptyState: Bool {
        hasLoaded && characters.isEmpty
    }

    var showsNotFound: Bool {
        hasLoaded && !characters.isEmpty && !query.isEmpty && shownCharacters.isEmpty
    }

    func sheetOpened(at page: Page?) {
        query = ""
        openedID = nil
        hasLoaded = false
        loadTask?.cancel()
        loadTask = Task {
            recentSearches = await readerStateCtrl.recentCharacterSearches()
            let characters = if let page { (try? await characterCtrl.characters(through: page)) ?? [] } else { [BookCharacter]() }
            guard !Task.isCancelled else { return }
            self.characters = characters
            hasLoaded = true
        }
    }

    func sheetClosed() {
        loadTask?.cancel()
    }

    func rowTapped(_ character: BookCharacter) {
        openedID = openedID == character.id ? nil : character.id
    }

    func passage(of character: BookCharacter) -> String {
        character.passage.map(ReferenceVM.quoted) ?? "No passage points to this character yet. Keep reading!"
    }

    func jumpTapped(_ character: BookCharacter) {
        guard let underlineID = character.underlineID else { return }
        saveRecentSearch()
        onJump(underlineID)
    }

    func queryChanged(_ query: String) {
        self.query = query
        openedID = nil
    }

    func querySubmitted() {
        saveRecentSearch()
    }

    func recentSearchTapped(_ query: String) {
        queryChanged(query)
    }

    func clearRecentSearchesTapped() {
        recentSearches = []
        Task { await readerStateCtrl.clearRecentCharacterSearches() }
    }

    private func saveRecentSearch() {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        Task {
            await readerStateCtrl.saveRecentCharacterSearch(query)
            recentSearches = await readerStateCtrl.recentCharacterSearches()
        }
    }
}
