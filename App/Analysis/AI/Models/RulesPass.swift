import Foundation

struct RulesPass: Sendable {
    let content: BookContent
    let sentences: [NumberedSentence]
    let analysis: ResolvedAnalysis
}
