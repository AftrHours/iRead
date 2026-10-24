import Foundation

struct LibRepo {
    private let epubParseSvc: EPUBParseSvc
    private let progRepo: ProgRepo
    private var booksFolder: URL { .applicationSupportDirectory.appending(path: "Books") }
    private var libraryURL: URL { booksFolder.appending(path: "library.json") }

    init(epubParseSvc: EPUBParseSvc, progRepo: ProgRepo) {
        self.epubParseSvc = epubParseSvc
        self.progRepo = progRepo
    }

    func fetchBooks() async throws -> [BookRecord] {
        var books: [BookRecord] = []
        for book in sampleBooks + importedBooks() {
            guard let progress = await progRepo.progress(for: book.id) else {
                books.append(book)
                continue
            }
            books.append(BookRecord(
                id: book.id,
                title: book.title,
                author: book.author,
                isContinueReading: book.isContinueReading,
                progress: progress.progress,
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

    private func importedBooks() -> [BookRecord] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = try? Data(contentsOf: libraryURL),
              let books = try? decoder.decode([BookRecord].self, from: data) else {
            return []
        }
        // Older builds saved the sample books into library.json too.
        let sampleIDs = Set(sampleBooks.map(\.id))
        return books.filter { !sampleIDs.contains($0.id) }
    }

    private var sampleBooks: [BookRecord] {
        [
            BookRecord(id: sampleID(1), title: "Little Women", author: "Louisa May Alcott", isContinueReading: true, progress: 0.3, dateAdded: Date(timeIntervalSince1970: 0)),
            BookRecord(id: sampleID(2), title: "A", author: "Tegar", isContinueReading: true, progress: 0.8, dateAdded: Date(timeIntervalSince1970: 0)),
            BookRecord(id: sampleID(3), title: "B", author: "Anna", isContinueReading: false, progress: 0.0, dateAdded: Date(timeIntervalSince1970: 0)),
            BookRecord(id: sampleID(4), title: "C", author: "Zee", isContinueReading: false, progress: 0.0, dateAdded: Date(timeIntervalSince1970: 0))
        ]
    }

    private func sampleID(_ number: UInt8) -> UUID {
        UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, number))
    }
}

private extension JSONEncoder {
    static var iso8601: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
