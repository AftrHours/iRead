import Foundation

actor BookContentRepoSample: BookContentRepo {
    private let epubParseSvc: any EPUBParseSvc
    private var parsing: Task<BookContent, any Error>?

    init(epubParseSvc: any EPUBParseSvc) {
        self.epubParseSvc = epubParseSvc
    }

    func content(for bookID: UUID) async throws -> BookContent {
        guard let url = Bundle.main.url(forResource: "little-women", withExtension: "epub") else {
            throw ContentError.notFound
        }
        let task = parsing ?? Task { [epubParseSvc] in try await epubParseSvc.parse(url) }
        parsing = task
        return try await task.value
    }
}
