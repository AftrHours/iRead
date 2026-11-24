import Foundation

struct BookState: Codable, Sendable {
    var returnFlow: String?
    var returnPosition: ReadingPosition?
    /// Newest first.
    var recentSearches: [String] = []
    var recentCharacterSearches: [String] = []

    init() {}

    // Files saved before a field existed still load, with that field empty.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        returnFlow = try container.decodeIfPresent(String.self, forKey: .returnFlow)
        returnPosition = try container.decodeIfPresent(ReadingPosition.self, forKey: .returnPosition)
        recentSearches = try container.decodeIfPresent([String].self, forKey: .recentSearches) ?? []
        recentCharacterSearches = try container.decodeIfPresent([String].self, forKey: .recentCharacterSearches) ?? []
    }
}
