import Foundation

actor BookContentRepo {
    private let epubParseSvc: EPUBParseSvc
    private var parsing: [UUID: Task<BookContent, any Error>] = [:]
    private var covers: [UUID: Data] = [:]

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

    func cover(for bookID: UUID) -> Data? {
        if let cover = covers[bookID] {
            return cover
        }
        guard let url = try? fileURL(for: bookID), let cover = try? epubParseSvc.cover(from: url) else { return nil }
        covers[bookID] = cover
        return cover
    }

    /// A copy of the book's EPUB named after its title, for the share sheet.
    func shareableFile(for book: BookRecord) throws -> URL {
        let folder = URL.temporaryDirectory.appending(path: "Share/\(book.id.uuidString)")
        let name = book.title.replacing(/[\/:]/, with: "-")
        let destination = folder.appending(path: "\(name).epub")
        try? FileManager.default.removeItem(at: folder)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: fileURL(for: book.id), to: destination)
        return destination
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
        guard let fileName = BookRecord.samples.first(where: { $0.book.id == bookID })?.fileName,
              let bundledURL = Bundle.main.url(forResource: fileName, withExtension: "epub") else {
            throw ContentError.notFound
        }
        return bundledURL
    }
}
