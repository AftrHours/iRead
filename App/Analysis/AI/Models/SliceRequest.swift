import Foundation

struct SliceMention: Sendable {
    let number: Int
    let text: String
    let sentence: Int
    let location: Int
}

struct SliceRequest: Sendable {
    let sentences: [ModelSentence]
    let mentions: [SliceMention]
    let cards: [CastCard]
}
