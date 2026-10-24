import Foundation

struct Token: Sendable {
    let text: String

    let lexicalClass: String

    let name: String?

    let lemma: String

    let start: Int
    let length: Int
}

enum TaggingEngine: String, Sendable {
    case naturalLanguage = "NaturalLanguage"

    case rules = "Fallback rules"

    case skipped = "Skipped"
}

struct SentenceTags: Sendable {
    let engine: TaggingEngine
    let tokens: [[Token]]

}
