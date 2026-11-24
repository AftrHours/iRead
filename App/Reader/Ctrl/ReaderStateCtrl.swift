import Foundation

actor ReaderStateCtrl {
    private static let maxRecentSearches = 10

    private let bookID: UUID
    private let readingSettingsRepo: ReadingSettingsRepo
    private let brightnessSvc: BrightnessSvc
    private let bookStateRepo: BookStateRepo
    private var bookState = BookState()

    init(bookID: UUID, readingSettingsRepo: ReadingSettingsRepo, brightnessSvc: BrightnessSvc, bookStateRepo: BookStateRepo) {
        self.bookID = bookID
        self.readingSettingsRepo = readingSettingsRepo
        self.brightnessSvc = brightnessSvc
        self.bookStateRepo = bookStateRepo
    }

    func settings() async -> ReadingSettings {
        await readingSettingsRepo.settings()
    }

    func save(_ settings: ReadingSettings) async {
        await readingSettingsRepo.save(settings)
    }

    func brightness() async -> Double {
        await brightnessSvc.brightness()
    }

    func changeBrightness(to value: Double) async {
        await brightnessSvc.changeBrightness(to: value)
    }

    func load() async {
        bookState = await bookStateRepo.state(for: bookID)
    }

    func hasReturnPosition() -> Bool {
        bookState.returnPosition != nil
    }

    func returnPosition() -> ReadingPosition? {
        bookState.returnPosition
    }

    func returnFlow() -> String? { bookState.returnFlow }

    func saveReturnPosition(_ position: ReadingPosition, flow: String? = nil) async {
        guard bookState.returnPosition == nil else { return }
        bookState.returnFlow = flow
        bookState.returnPosition = position
        await bookStateRepo.save(bookState, for: bookID)
    }

    func clearReturnPosition() async {
        bookState.returnFlow = nil
        bookState.returnPosition = nil
        await bookStateRepo.save(bookState, for: bookID)
    }

    func recentSearches() -> [String] {
        bookState.recentSearches
    }

    func saveRecentSearch(_ query: String) async {
        bookState.recentSearches = Self.adding(query, to: bookState.recentSearches)
        await bookStateRepo.save(bookState, for: bookID)
    }

    func clearRecentSearches() async {
        bookState.recentSearches = []
        await bookStateRepo.save(bookState, for: bookID)
    }

    func recentCharacterSearches() -> [String] {
        bookState.recentCharacterSearches
    }

    func saveRecentCharacterSearch(_ query: String) async {
        bookState.recentCharacterSearches = Self.adding(query, to: bookState.recentCharacterSearches)
        await bookStateRepo.save(bookState, for: bookID)
    }

    func clearRecentCharacterSearches() async {
        bookState.recentCharacterSearches = []
        await bookStateRepo.save(bookState, for: bookID)
    }

    private static func adding(_ query: String, to searches: [String]) -> [String] {
        var searches = searches
        searches.removeAll { $0.caseInsensitiveCompare(query) == .orderedSame }
        searches.insert(query, at: 0)
        return Array(searches.prefix(maxRecentSearches))
    }
}
