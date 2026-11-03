import Foundation
import UnderlineEngine

/// A phrase the engine considered and gave no underline, and why.
struct DroppedPhrase: Codable, Sendable {
    let sentence: Int
    let phrase: String
    let reason: DropReason

    init?(_ record: UnderlineRecord) {
        guard let reason = record.dropped else { return nil }
        sentence = record.sentence
        phrase = record.phrase
        self.reason = reason
    }
}
