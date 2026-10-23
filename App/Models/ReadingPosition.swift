import Foundation

struct ReadingPosition: Codable, Comparable, Sendable {
    let paragraph: Int
    let charOffset: Int

    static func < (lhs: Self, rhs: Self) -> Bool {
        (lhs.paragraph, lhs.charOffset) < (rhs.paragraph, rhs.charOffset)
    }
}
