import Foundation

struct AnalysisSnapshot: Sendable {
    let book: BookAnalysis
    let resolved: ResolvedAnalysis
    let content: BookContent
    let chaptersDone: Int
    let chaptersTotal: Int
    let modelCalls: Int
    let failedSlices: Int
    let usesModel: Bool
}
