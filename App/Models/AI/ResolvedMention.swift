import Foundation

enum MentionForm: String, Sendable {
    case name
    case description
}

struct ResolvedMention: Sendable {
    let sentence: Int

    let location: Int
    let length: Int
    let text: String
    let form: MentionForm

    let head: String

    let modifiers: [String]

    var entity: Int?
    var decidedBy: DecidedBy?
}
