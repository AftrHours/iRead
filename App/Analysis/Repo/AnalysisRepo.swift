import Foundation

actor AnalysisRepo {
    private let bookContentRepo: BookContentRepo
    private let analysisScheduleSvc: AnalysisScheduleSvc
    private var passes: [UUID: Task<RulesPass, any Error>] = [:]
    private var refinements: [UUID: Task<AnalysisSnapshot, any Error>] = [:]
    private var latest: [UUID: AnalysisSnapshot] = [:]
    private var progress: [UUID: EngineProgress] = [:]

    init(bookContentRepo: BookContentRepo, analysisScheduleSvc: AnalysisScheduleSvc) {
        self.bookContentRepo = bookContentRepo
        self.analysisScheduleSvc = analysisScheduleSvc
    }

    func analysis(for bookID: UUID) async throws -> BookAnalysis {
        try await snapshot(for: bookID).book
    }

    func snapshot(for bookID: UUID) async throws -> AnalysisSnapshot {
        if let snapshot = latest[bookID] { return snapshot }
        let pass = try await rulesPass(for: bookID)
        if let snapshot = latest[bookID] { return snapshot }
        let snapshot = analysisScheduleSvc.analysis(from: pass)
        latest[bookID] = snapshot
        return snapshot
    }

    func refinedAnalysis(for bookID: UUID) async throws -> BookAnalysis {
        let pass = try await rulesPass(for: bookID)
        let task = refinements[bookID] ?? Task.detached { [analysisScheduleSvc, self] in
            await analysisScheduleSvc.refinedAnalysis(from: pass) { progress in
                Task { await self.record(progress, for: bookID) }
            }
        }
        refinements[bookID] = task
        let snapshot = try await task.value
        latest[bookID] = snapshot
        return snapshot.book
    }

    func progress(for bookID: UUID) -> EngineProgress? {
        progress[bookID]
    }

    private func record(_ newProgress: EngineProgress, for bookID: UUID) {
        if newProgress.done >= progress[bookID]?.done ?? 0 {
            progress[bookID] = newProgress
        }
    }

    private func rulesPass(for bookID: UUID) async throws -> RulesPass {
        let task = passes[bookID] ?? Task.detached { [bookContentRepo, analysisScheduleSvc] in
            analysisScheduleSvc.rulesPass(for: try await bookContentRepo.content(for: bookID))
        }
        passes[bookID] = task
        return try await task.value
    }
}
