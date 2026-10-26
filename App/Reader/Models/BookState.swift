import Foundation

struct BookState: Codable, Sendable {
    var returnPosition: ReadingPosition?
    /// Symbols the reader edited, by entity ID.
    var editedSymbols: [String: SymbolStyle] = [:]
    /// Newest first.
    var recentSearches: [String] = []

    init() {}

    // Files saved before a field existed still load, with that field empty.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        returnPosition = try container.decodeIfPresent(ReadingPosition.self, forKey: .returnPosition)
        editedSymbols = try container.decodeIfPresent([String: SymbolStyle].self, forKey: .editedSymbols) ?? [:]
        recentSearches = try container.decodeIfPresent([String].self, forKey: .recentSearches) ?? []
    }
}
