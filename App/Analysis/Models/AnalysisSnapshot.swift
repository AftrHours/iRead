import Foundation

struct AnalysisSnapshot: Sendable {
    let pass: RulesPass
    let resolved: ResolvedAnalysis
    let book: BookAnalysis
    let isModelAvailable: Bool
    let modelDuration: Duration?
}
