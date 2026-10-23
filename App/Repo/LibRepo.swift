import Foundation

struct LibRepo {
    private var booksFolder: URL { .applicationSupportDirectory.appending(path: "Books") }
    private var libraryURL: URL { booksFolder.appending(path: "library.json") }

    func fetchBooks() async throws -> [BookRecord] {
        let storedBooks: [BookRecord]
        let libraryDecoder = JSONDecoder()
        libraryDecoder.dateDecodingStrategy = .iso8601
        if let data = try? Data(contentsOf: libraryURL),
           let decoded = try? libraryDecoder.decode([BookRecord].self, from: data) {
            storedBooks = decoded
        } else {
            storedBooks = [
                BookRecord(id: sampleID(1), title: "Little Women", author: "Louisa May Alcott", isContinueReading: true, progress: 0.3, dateAdded: Date(timeIntervalSince1970: 0)),
                BookRecord(id: sampleID(2), title: "A", author: "Tegar", isContinueReading: true, progress: 0.8, dateAdded: Date(timeIntervalSince1970: 0)),
                BookRecord(id: sampleID(3), title: "B", author: "Anna", isContinueReading: false, progress: 0.0, dateAdded: Date(timeIntervalSince1970: 0)),
                BookRecord(id: sampleID(4), title: "C", author: "Zee", isContinueReading: false, progress: 0.0, dateAdded: Date(timeIntervalSince1970: 0))
            ]
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return storedBooks.map { book in
            let progressURL = booksFolder.appending(path: "\(book.id.uuidString)/progress.json")
            guard let data = try? Data(contentsOf: progressURL),
                  let progress = try? decoder.decode(ReadingProgress.self, from: data) else { return book }
            return BookRecord(
                id: book.id,
                title: book.title,
                author: book.author,
                isContinueReading: book.isContinueReading,
                progress: progress.progress,
                dateAdded: book.dateAdded,
                lastReadAt: progress.lastReadAt
            )
        }
    }

    func importBook(from sourceURL: URL) async throws -> BookRecord {
        let hasAccess = sourceURL.startAccessingSecurityScopedResource()
        defer { if hasAccess { sourceURL.stopAccessingSecurityScopedResource() } }

        let metadata = try EPUBParseSvc().metadata(from: sourceURL)

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
        var books = try await fetchBooks()
        books.append(book)
        try JSONEncoder.iso8601.encode(books).write(to: libraryURL, options: .atomic)
        return book
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
