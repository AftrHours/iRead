import Foundation

struct BookRecord: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String
    let author: String
    let isContinueReading: Bool
    let progress: Double
    let dateAdded: Date
    let lastReadAt: Date?

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
        lastReadAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.isContinueReading = isContinueReading
        self.progress = progress
        self.dateAdded = dateAdded
        self.lastReadAt = lastReadAt
    }
}

extension BookRecord {
    /// Books bundled in App/Resources, shown in the library before anything is imported.
    static let samples: [(book: BookRecord, fileName: String)] = [
        sample(1, "Little Women", by: "Louisa May Alcott", progress: 0.3, file: "little-women"),
        sample(5, "Anne of Green Gables", by: "L. M. Montgomery", file: "anne-of-green-gables"),
        sample(6, "Moby Dick", by: "Herman Melville", file: "moby-dick"),
        sample(7, "Pride and Prejudice", by: "Jane Austen", file: "pride-and-prejudice"),
        sample(8, "The Adventures of Sherlock Holmes", by: "Arthur Conan Doyle", file: "the-adventures-of-sherlock-holmes")
    ]

    private static func sample(_ number: UInt8, _ title: String, by author: String, progress: Double = 0,
                               file: String) -> (book: BookRecord, fileName: String) {
        let book = BookRecord(
            id: sampleID(number),
            title: title,
            author: author,
            isContinueReading: progress > 0,
            progress: progress,
            dateAdded: Date(timeIntervalSince1970: 0)
        )
        return (book, file)
    }

    private static func sampleID(_ number: UInt8) -> UUID {
        UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, number))
    }
}
