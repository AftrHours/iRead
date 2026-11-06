import Foundation

enum Verdict: String, Codable, Sendable {
    case up, down
}

/// A thumbs up or down on an underline's reference passage, with what an item of UnderlineEngine's golden set needs.
/// Sentences count from the chapter's first sentence, like the golden set's.
struct UnderlineRating: Codable, Sendable, Equatable {
    /// The book's fingerprint.
    let book: String
    let bookTitle: String
    let chapterIndex: Int
    let underlineID: String
    /// nil: the reader took the rating back.
    let verdict: Verdict?
    let phrase: String
    let kind: String
    let sentence: Int
    let sentenceText: String
    let reference: Int
    let referenceText: String
    /// "model" or "rules".
    let decidedBy: String
    let engineVersion: Int
}
