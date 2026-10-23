import Foundation

struct ContextPassage: Sendable {
    let paragraph: Int
    let range: NSRange
    let text: String

    var start: ReadingPosition {
        ReadingPosition(paragraph: paragraph, charOffset: range.location)
    }
}
