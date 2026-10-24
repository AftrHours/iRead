import Foundation

struct BookRecord: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String
    let author: String
    let isContinueReading: Bool
    let progress: Double
    let dateAdded: Date
    let lastReadAt: Date?

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
