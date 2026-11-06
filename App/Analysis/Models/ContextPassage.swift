import Foundation

struct ContextPassage: Codable, Sendable, Hashable {
    let sentence: Int
    let paragraph: Int
    let range: NSRange
    let text: String

    var start: ReadingPosition {
        ReadingPosition(paragraph: paragraph, charOffset: range.location)
    }
}
