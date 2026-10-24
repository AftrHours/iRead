import Foundation

struct RulesPass: Sendable {
    let content: BookContent
    let sentences: [NumberedSentence]
    let rules: EntityResolveSvc.RulesResult
}
