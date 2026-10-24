import Foundation

struct Token: Sendable {
    let text: String
    let lexicalClass: String
    let name: String?
    let lemma: String
    let start: Int
    let length: Int
}

struct SentenceTags: Sendable {
    let tokens: [[Token]]
}
