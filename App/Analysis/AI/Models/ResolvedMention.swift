import Foundation

enum MentionForm: Sendable, Codable {
    case name
    case description
}

struct ResolvedMention: Sendable, Codable {
    let sentence: Int
    let location: Int
    let length: Int
    let text: String
    let form: MentionForm
    let head: String
    let modifiers: [String]
    var entity: Int?
    var decidedBy: DecidedBy?
    var isUndecided = false
}
