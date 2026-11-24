import Foundation

struct Mark: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case underline(id: String)
        case highlight
    }

    let range: NSRange
    let kind: Kind

    var isUnderline: Bool {
        if case .underline = kind { true } else { false }
    }

    var underlineID: String? {
        if case .underline(let id) = kind { id } else { nil }
    }
}
