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

    func saveReturnPosition(_ position: ReadingPosition) async {
        guard bookState.returnPosition == nil else { return }
        bookState.returnPosition = position
        await bookStateRepo.save(bookState, for: bookID)
    }

    func clearReturnPosition() async {
        bookState.returnPosition = nil
        await bookStateRepo.save(bookState, for: bookID)
    }

    func editedSymbols() -> [String: SymbolStyle] {
        bookState.editedSymbols
    }

    func saveSymbol(_ style: SymbolStyle, forEntity entityID: String) async {
        bookState.editedSymbols[entityID] = style
        await bookStateRepo.save(bookState, for: bookID)
    }

    func recentSearches() -> [String] {
        bookState.recentSearches
    }

    func saveRecentSearch(_ query: String) async {
        bookState.recentSearches.removeAll { $0.caseInsensitiveCompare(query) == .orderedSame }
        bookState.recentSearches.insert(query, at: 0)
        bookState.recentSearches = Array(bookState.recentSearches.prefix(Self.maxRecentSearches))
        await bookStateRepo.save(bookState, for: bookID)
    }

    func clearRecentSearches() async {
        bookState.recentSearches = []
        await bookStateRepo.save(bookState, for: bookID)
    }
}
