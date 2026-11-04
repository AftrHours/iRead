import Foundation

struct Mark: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case underline(id: String)
        case highlight
        case symbol(SymbolStyle, entityName: String, mentionIndex: Int)
    }

    let range: NSRange
    let kind: Kind

    var isUnderline: Bool {
        if case .underline = kind { true } else { false }
    }
}
