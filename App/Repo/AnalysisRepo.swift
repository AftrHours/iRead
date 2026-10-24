import Foundation

actor AnalysisRepo {
    private let bookContentRepo: BookContentRepo
    private let analysisScheduleSvc: AnalysisScheduleSvc
    private var analyses: [UUID: Task<BookAnalysis, any Error>] = [:]

    init(bookContentRepo: BookContentRepo, analysisScheduleSvc: AnalysisScheduleSvc) {
        self.bookContentRepo = bookContentRepo
        self.analysisScheduleSvc = analysisScheduleSvc
    }

    func analysis(for bookID: UUID) async throws -> BookAnalysis {
        let task = analyses[bookID] ?? Task.detached { [bookContentRepo, analysisScheduleSvc] in
            let content = try await bookContentRepo.content(for: bookID)
            return analysisScheduleSvc.analysis(for: content)
        }
        analyses[bookID] = task
        return try await task.value
    }
}
