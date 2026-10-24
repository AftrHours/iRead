import Foundation

struct Page: Equatable, Sendable {
    let number: Int
    let chapterIndex: Int
    let range: NSRange
    let text: String
}
