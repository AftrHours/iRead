import Foundation

struct LibRepo {
    private let epubParseSvc: EPUBParseSvc
    private let progRepo: ProgRepo
    private var booksFolder: URL { .applicationSupportDirectory.appending(path: "Books") }
    private var libraryURL: URL { booksFolder.appending(path: "library.json") }
    private var hiddenSamplesURL: URL { booksFolder.appending(path: "hidden-samples.json") }

    init(epubParseSvc: EPUBParseSvc, progRepo: ProgRepo) {
        self.epubParseSvc = epubParseSvc
        self.progRepo = progRepo
    }

    func fetchBooks() async throws -> [BookRecord] {
        var books: [BookRecord] = []
        let hiddenIDs = hiddenSampleIDs()
        let samples = BookRecord.samples.map(\.book).filter { !hiddenIDs.contains($0.id) }
        for book in samples + importedBooks() {
            guard let progress = await progRepo.progress(for: book.id) else {
                books.append(book)
                continue
            }
            books.append(BookRecord(
                id: book.id,
                title: book.title,
                author: book.author,
                isContinueReading: book.isContinueReading,
                // A finished book shows as fully read, even if it was marked finished part way through.
                progress: progress.finishedAt == nil ? progress.progress : 1,
                dateAdded: book.dateAdded,
                lastReadAt: progress.lastReadAt
            ))
        }
        return books
    }

    func importBook(from sourceURL: URL) async throws -> BookRecord {
        let hasAccess = sourceURL.startAccessingSecurityScopedResource()
        defer { if hasAccess { sourceURL.stopAccessingSecurityScopedResource() } }

        let metadata = try epubParseSvc.metadata(from: sourceURL)

        try FileManager.default.createDirectory(at: booksFolder, withIntermediateDirectories: true)
        let id = UUID()
        let destination = booksFolder.appending(path: "\(id.uuidString)/book.epub")
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: sourceURL, to: destination)

        let filename = sourceURL.deletingPathExtension().lastPathComponent
        let book = BookRecord(
            id: id,
            title: metadata.title ?? filename,
            author: metadata.author ?? "Unknown Author",
            isContinueReading: false,
            progress: 0,
            dateAdded: .now
        )
        var books = importedBooks()
        books.append(book)
        try JSONEncoder.iso8601.encode(books).write(to: libraryURL, options: .atomic)
        return book
    }

    func setFinished(_ isFinished: Bool, for book: BookRecord) async {
        await progRepo.setFinished(isFinished, for: book.id)
    }

    func resetProgress(for book: BookRecord) async {
        await progRepo.resetProgress(for: book.id)
    }

    /// Deletes an imported book and its files. A sample book is only hidden, since it lives in the app bundle.
    func remove(_ book: BookRecord) throws {
        try FileManager.default.createDirectory(at: booksFolder, withIntermediateDirectories: true)
        if BookRecord.samples.contains(where: { $0.book.id == book.id }) {
            try JSONEncoder().encode(hiddenSampleIDs().union([book.id])).write(to: hiddenSamplesURL, options: .atomic)
            return
        }
        let books = importedBooks().filter { $0.id != book.id }
        try JSONEncoder.iso8601.encode(books).write(to: libraryURL, options: .atomic)
        try? FileManager.default.removeItem(at: booksFolder.appending(path: book.id.uuidString))
    }

    private func hiddenSampleIDs() -> Set<UUID> {
        guard let data = try? Data(contentsOf: hiddenSamplesURL) else { return [] }
        return (try? JSONDecoder().decode(Set<UUID>.self, from: data)) ?? []
    }

    private func importedBooks() -> [BookRecord] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = try? Data(contentsOf: libraryURL),
              let books = try? decoder.decode([BookRecord].self, from: data) else {
            return []
        }
        // Older builds saved the sample books into library.json too.
        let sampleIDs = Set(BookRecord.samples.map(\.book.id))
        return books.filter { !sampleIDs.contains($0.id) }
    }
}

private extension JSONEncoder {
    static var iso8601: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
