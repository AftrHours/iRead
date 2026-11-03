import Foundation

/// What a tapped underline shows: the phrase and the earlier passage that explains it.
struct UnderlineReference: Sendable {
    let phrase: String
    let passage: ContextPassage
}
