import Foundation

struct LinkRequest: Sendable {
    let mention: ResolvedMention
    let sentences: [ModelSentence]
    let candidates: [ModelCandidate]
}
