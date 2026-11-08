import Foundation

struct BookRecord: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String
    let author: String
    let isContinueReading: Bool
    let progress: Double
    let dateAdded: Date
    let lastReadAt: Date?
    /// The Project Gutenberg ebook number, when the EPUB names one. nil in library.json files from older builds.
    let gutenbergNumber: Int?
    /// `BookContent.fingerprint`, saved at import. nil for the bundled samples and books imported by older builds.
    let fingerprint: String?

    var isFinished: Bool {
        progress >= 1
    }

    init(
        id: UUID,
        title: String,
        author: String,
        isContinueReading: Bool,
        progress: Double,
        dateAdded: Date = .now,
        lastReadAt: Date? = nil,
        gutenbergNumber: Int? = nil,
        fingerprint: String? = nil
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.isContinueReading = isContinueReading
        self.progress = progress
        self.dateAdded = dateAdded
        self.lastReadAt = lastReadAt
        self.gutenbergNumber = gutenbergNumber
        self.fingerprint = fingerprint
    }

    /// What tells this book apart from another copy of it (see DuplicateRules).
    var identity: BookIdentity {
        BookIdentity(gutenbergNumber: gutenbergNumber, title: title, author: author, fingerprint: fingerprint)
    }
}

extension BookRecord {
    /// Books bundled in App/Resources, shown in the library before anything is imported.
    static let samples: [(book: BookRecord, fileName: String)] = [
        // The Gutenberg numbers are the ones in each EPUB's dc:identifier (checked by LIB-07).
        sample(1, "Little Women", by: "Louisa May Alcott", progress: 0.3, file: "little-women", gutenberg: 514),
        sample(5, "Anne of Green Gables", by: "L. M. Montgomery", file: "anne-of-green-gables", gutenberg: 45),
        sample(6, "Moby Dick", by: "Herman Melville", file: "moby-dick", gutenberg: 2701),
        sample(7, "Pride and Prejudice", by: "Jane Austen", file: "pride-and-prejudice", gutenberg: 1342),
        sample(8, "The Adventures of Sherlock Holmes", by: "Arthur Conan Doyle", file: "the-adventures-of-sherlock-holmes",
               gutenberg: 1661)
    ]

    private static func sample(_ number: UInt8, _ title: String, by author: String, progress: Double = 0,
                               file: String, gutenberg: Int) -> (book: BookRecord, fileName: String) {
        let book = BookRecord(
            id: sampleID(number),
            title: title,
            author: author,
            isContinueReading: progress > 0,
            progress: progress,
            dateAdded: Date(timeIntervalSince1970: 0),
            gutenbergNumber: gutenberg
        )
        return (book, file)
    }

    private static func sampleID(_ number: UInt8) -> UUID {
        UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, number))
    }
}
