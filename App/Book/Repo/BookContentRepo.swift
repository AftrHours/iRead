import Foundation

enum BookContentRepoKnobs {
    /// Parsed books kept in memory: the open book, plus one so reopening the last book is instant.
    static let keptBooks = 2
}

actor BookContentRepo {
    private let epubParseSvc: any EPUBParseSvc
    private let booksFolder: URL
    private var parsing: [UUID: Task<BookContent, any Error>] = [:]
    /// The books in `parsing`, least recently used first.
    private var recentBookIDs: [UUID] = []
    private var covers: [UUID: Data] = [:]

    init(epubParseSvc: any EPUBParseSvc, folder: URL = .applicationSupportDirectory.appending(path: "Books")) {
        self.epubParseSvc = epubParseSvc
        booksFolder = folder
    }

    func content(for bookID: UUID) async throws -> BookContent {
        let task = try parsing[bookID] ?? parseTask(for: bookID)
        parsing[bookID] = task
        markUsed(bookID)
        do {
            return try await task.value
        } catch {
            // Only drop the task that failed, so a retry can start a fresh parse.
            if parsing[bookID] == task {
                forgetParse(of: bookID)
            }
            throw error
        }
    }

    /// Drops a removed book's parse and cover.
    func forget(_ bookID: UUID) {
        forgetParse(of: bookID)
        covers[bookID] = nil
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

    /// Callers already waiting on a dropped parse still get its content.
    private func markUsed(_ bookID: UUID) {
        recentBookIDs.removeAll { $0 == bookID }
        recentBookIDs.append(bookID)
        while recentBookIDs.count > BookContentRepoKnobs.keptBooks {
            parsing[recentBookIDs.removeFirst()] = nil
        }
    }

    private func forgetParse(of bookID: UUID) {
        parsing[bookID] = nil
        recentBookIDs.removeAll { $0 == bookID }
    }

    private func parseTask(for bookID: UUID) throws -> Task<BookContent, any Error> {
        let url = try fileURL(for: bookID)
        return Task { [epubParseSvc] in try await epubParseSvc.parse(url) }
    }

    private func fileURL(for bookID: UUID) throws -> URL {
        let importedURL = booksFolder.appending(path: "\(bookID.uuidString)/book.epub")
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
