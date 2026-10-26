import Foundation

struct Mark: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case underline
        case highlight
        case symbol(SymbolStyle, entityName: String)
    }

    let mentionIndex: Int
    let range: NSRange
    let kind: Kind
}
