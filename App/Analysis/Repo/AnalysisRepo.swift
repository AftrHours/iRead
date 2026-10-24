import Foundation

actor AnalysisRepo {
    private let bookContentRepo: BookContentRepo
    private let analysisScheduleSvc: AnalysisScheduleSvc
    private var passes: [UUID: Task<RulesPass, any Error>] = [:]
    private var refinements: [UUID: Task<BookAnalysis, any Error>] = [:]
    private var latest: [UUID: BookAnalysis] = [:]

    init(bookContentRepo: BookContentRepo, analysisScheduleSvc: AnalysisScheduleSvc) {
        self.bookContentRepo = bookContentRepo
        self.analysisScheduleSvc = analysisScheduleSvc
    }

    func analysis(for bookID: UUID) async throws -> BookAnalysis {
        if let analysis = latest[bookID] { return analysis }
        let pass = try await rulesPass(for: bookID)
        if let analysis = latest[bookID] { return analysis }
        let analysis = analysisScheduleSvc.analysis(from: pass)
        latest[bookID] = analysis
        return analysis
    }

    func refinedAnalysis(for bookID: UUID) async throws -> BookAnalysis {
        let pass = try await rulesPass(for: bookID)
        let task = refinements[bookID] ?? Task.detached { [analysisScheduleSvc] in
            await analysisScheduleSvc.refinedAnalysis(from: pass)
        }
        refinements[bookID] = task
        let analysis = try await task.value
        latest[bookID] = analysis
        return analysis
    }

    private func rulesPass(for bookID: UUID) async throws -> RulesPass {
        let task = passes[bookID] ?? Task.detached { [bookContentRepo, analysisScheduleSvc] in
            analysisScheduleSvc.rulesPass(for: try await bookContentRepo.content(for: bookID))
        }
        passes[bookID] = task
        return try await task.value
    }
}
