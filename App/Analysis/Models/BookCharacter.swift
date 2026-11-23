import Foundation

/// Not `Character`, which is Swift's.
struct BookCharacter: Identifiable, Hashable, Sendable {
    /// "Jo/Josephine March"
    let name: String
    let names: [String]
    /// The engine underline whose passage describes them best.
    let underlineID: String?
    let passage: String?

    var id: String { name }
}

struct NameMention: Hashable, Sendable {
    let name: String
    let position: ReadingPosition
}
