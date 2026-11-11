import Foundation

struct LibRepo {
    private let epubParseSvc: any EPUBParseSvc
    private let booksFolder: URL
    private var libraryURL: URL { booksFolder.appending(path: "library.json") }
    private var hiddenSamplesURL: URL { booksFolder.appending(path: "hidden-samples.json") }
    private var renamedTitlesURL: URL { booksFolder.appending(path: "renamed-titles.json") }

    init(epubParseSvc: any EPUBParseSvc, folder: URL = .applicationSupportDirectory.appending(path: "Books")) {
        self.epubParseSvc = epubParseSvc
        booksFolder = folder
    }

    /// The sample books that aren't hidden, then the imported books, without reading progress.
    func fetchBooks() throws -> [BookRecord] {
        let hiddenIDs = hiddenSampleIDs()
        let titles = renamedTitles()
        let samples = BookRecord.samples.map(\.book)
            .filter { !hiddenIDs.contains($0.id) }
            .map { book in copy(book, titled: titles[book.id.uuidString] ?? book.title) }
        return samples + importedBooks()
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

    /// Renames the library entry while leaving the imported EPUB's metadata and bytes intact.
    func rename(_ book: BookRecord, to title: String) throws {
        try FileManager.default.createDirectory(at: booksFolder, withIntermediateDirectories: true)
        if BookRecord.samples.contains(where: { $0.book.id == book.id }) {
            var titles = renamedTitles()
            titles[book.id.uuidString] = title
            try JSONEncoder().encode(titles).write(to: renamedTitlesURL, options: .atomic)
            return
        }

        var books = importedBooks()
        guard let index = books.firstIndex(where: { $0.id == book.id }) else { return }
        books[index] = copy(books[index], titled: title)
        try JSONEncoder.iso8601.encode(books).write(to: libraryURL, options: .atomic)
    }

    private func hiddenSampleIDs() -> Set<UUID> {
        guard let data = try? Data(contentsOf: hiddenSamplesURL) else { return [] }
        return (try? JSONDecoder().decode(Set<UUID>.self, from: data)) ?? []
    }

    private func renamedTitles() -> [String: String] {
        guard let data = try? Data(contentsOf: renamedTitlesURL) else { return [:] }
        return (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
    }

    private func copy(_ book: BookRecord, titled title: String) -> BookRecord {
        BookRecord(id: book.id, title: title, author: book.author, isContinueReading: book.isContinueReading,
                   progress: book.progress, dateAdded: book.dateAdded, lastReadAt: book.lastReadAt)
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
