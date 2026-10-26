import Foundation

struct MentionAssignment: Sendable {
    let mention: Int
    let card: Int?
    let evidence: Int
}

struct NamedSpan: Sendable {
    let text: String
    let sentence: Int
}

struct NamePair: Sendable {
    let first: String
    let second: String
    let evidence: Int
}

struct TraitNote: Sendable {
    let card: Int
    let text: String
    let sentence: Int
}

struct SliceReading: Sendable {
    var assignments: [MentionAssignment]
    var missedNames: [NamedSpan]
    var sameNames: [NamePair]
    var traits: [TraitNote]
}
