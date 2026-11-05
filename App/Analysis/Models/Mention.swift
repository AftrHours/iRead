import Foundation

struct Mention: Sendable {
    let entityID: String
    let paragraph: Int
    let range: NSRange
}
