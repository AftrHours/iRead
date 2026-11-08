import Foundation

struct LibRepo {
    private let epubParseSvc: any EPUBParseSvc
    private let booksFolder: URL
    private var libraryURL: URL { booksFolder.appending(path: "library.json") }
    private var hiddenSamplesURL: URL { booksFolder.appending(path: "hidden-samples.json") }

    init(epubParseSvc: any EPUBParseSvc, folder: URL = .applicationSupportDirectory.appending(path: "Books")) {
        self.epubParseSvc = epubParseSvc
        booksFolder = folder
    }

    /// The sample books that aren't hidden, then the imported books, without reading progress.
    func fetchBooks() throws -> [BookRecord] {
        let hiddenIDs = hiddenSampleIDs()
        return BookRecord.samples.map(\.book).filter { !hiddenIDs.contains($0.id) } + importedBooks()
    }

    /// Reads the EPUB once (its whole text, for the fingerprint). Throws `ContentError.unreadable` for a broken file.
    func candidate(for sourceURL: URL) async throws -> ImportCandidate {
        let hasAccess = sourceURL.startAccessingSecurityScopedResource()
        defer { if hasAccess { sourceURL.stopAccessingSecurityScopedResource() } }

        let metadata = try epubParseSvc.metadata(from: sourceURL)
        let content = try await epubParseSvc.parse(sourceURL)
        let title = metadata.title ?? sourceURL.deletingPathExtension().lastPathComponent
        let author = metadata.author ?? "Unknown Author"
        let identity = BookIdentity(gutenbergNumber: GutenbergNumber.from(identifiers: metadata.identifiers), title: title,
                                    author: author, fingerprint: content.fingerprint)
        return ImportCandidate(title: title, author: author, identity: identity)
    }

    func importBook(from sourceURL: URL) async throws -> BookRecord {
        try importBook(from: sourceURL, as: await candidate(for: sourceURL))
    }

    func importBook(from sourceURL: URL, as candidate: ImportCandidate) throws -> BookRecord {
        let hasAccess = sourceURL.startAccessingSecurityScopedResource()
        defer { if hasAccess { sourceURL.stopAccessingSecurityScopedResource() } }

        try FileManager.default.createDirectory(at: booksFolder, withIntermediateDirectories: true)
        let id = UUID()
        let destination = booksFolder.appending(path: "\(id.uuidString)/book.epub")
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: sourceURL, to: destination)

        let book = BookRecord(
            id: id,
            title: candidate.title,
            author: candidate.author,
            isContinueReading: false,
            progress: 0,
            dateAdded: .now,
            gutenbergNumber: candidate.identity.gutenbergNumber,
            fingerprint: candidate.identity.fingerprint
        )
        var books = importedBooks()
        books.append(book)
        try JSONEncoder.iso8601.encode(books).write(to: libraryURL, options: .atomic)
        return book
    }

    /// Sample books the reader removed.
    func hiddenSamples() -> [BookRecord] {
        let hiddenIDs = hiddenSampleIDs()
        return BookRecord.samples.map(\.book).filter { hiddenIDs.contains($0.id) }
    }

    func unhideSample(_ id: UUID) throws {
        try FileManager.default.createDirectory(at: booksFolder, withIntermediateDirectories: true)
        try JSONEncoder().encode(hiddenSampleIDs().subtracting([id])).write(to: hiddenSamplesURL, options: .atomic)
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
