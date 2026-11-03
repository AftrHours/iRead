import Foundation

struct Mark: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case underline(id: String)
        case highlight
    }

    let range: NSRange
    let kind: Kind
}
