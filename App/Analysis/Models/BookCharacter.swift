import Foundation

/// Not `Character`, which is Swift's.
struct BookCharacter: Identifiable, Hashable, Sendable {
    /// "Jo/Josephine March"
    let name: String
    let names: [String]
    /// The passage that describes them best, nil when none does yet.
    let passage: ContextPassage?

    var id: String { name }
}

struct NameMention: Hashable, Sendable {
    let name: String
    let position: ReadingPosition
}
