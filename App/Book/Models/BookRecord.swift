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
        (BookRecord(id: sampleID(1), title: "Little Women", author: "Louisa May Alcott", isContinueReading: true, progress: 0.3, dateAdded: Date(timeIntervalSince1970: 0)), "little-women"),
        (BookRecord(id: sampleID(5), title: "Anne of Green Gables", author: "L. M. Montgomery", isContinueReading: false, progress: 0, dateAdded: Date(timeIntervalSince1970: 0)), "anne-of-green-gables"),
        (BookRecord(id: sampleID(6), title: "Moby Dick", author: "Herman Melville", isContinueReading: false, progress: 0, dateAdded: Date(timeIntervalSince1970: 0)), "moby-dick"),
        (BookRecord(id: sampleID(7), title: "Pride and Prejudice", author: "Jane Austen", isContinueReading: false, progress: 0, dateAdded: Date(timeIntervalSince1970: 0)), "pride-and-prejudice"),
        (BookRecord(id: sampleID(8), title: "The Adventures of Sherlock Holmes", author: "Arthur Conan Doyle", isContinueReading: false, progress: 0, dateAdded: Date(timeIntervalSince1970: 0)), "the-adventures-of-sherlock-holmes")
    ]

    private static func sampleID(_ number: UInt8) -> UUID {
        UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, number))
    }
}
