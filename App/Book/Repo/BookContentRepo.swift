import Foundation

actor BookContentRepo {
    private let epubParseSvc: EPUBParseSvc
    private var parsing: [UUID: Task<BookContent, any Error>] = [:]

    init(epubParseSvc: EPUBParseSvc) {
        self.epubParseSvc = epubParseSvc
    }

    func content(for bookID: UUID) async throws -> BookContent {
        let task = try parsing[bookID] ?? parseTask(for: bookID)
        parsing[bookID] = task
        do {
            return try await task.value
        } catch {
            // Only drop the task that failed, so a retry can start a fresh parse.
            if parsing[bookID] == task {
                parsing[bookID] = nil
            }
            throw error
        }
    }

    private func parseTask(for bookID: UUID) throws -> Task<BookContent, any Error> {
        let url = try fileURL(for: bookID)
        return Task { [epubParseSvc] in try await epubParseSvc.parse(url) }
    }

    private func fileURL(for bookID: UUID) throws -> URL {
        let importedURL = URL.applicationSupportDirectory.appending(path: "Books/\(bookID.uuidString)/book.epub")
        if FileManager.default.fileExists(atPath: importedURL.path) {
            return importedURL
        }
        guard let bundledURL = Bundle.main.url(forResource: "little-women", withExtension: "epub") else {
            throw ContentError.notFound
        }
        return bundledURL
    }
}
