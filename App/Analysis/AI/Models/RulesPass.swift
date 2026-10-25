import Foundation

struct RulesPass: Sendable {
    let content: BookContent
    let sentences: [NumberedSentence]
    let analysis: ResolvedAnalysis
    let usesNaturalLanguage: Bool
    let duration: Duration
}
