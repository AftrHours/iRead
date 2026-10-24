import Foundation

struct ReadingProgress: Codable, Sendable {
    let bookID: UUID
    let position: ReadingPosition
    let chapterIndex: Int
    let progress: Double
    let lastReadAt: Date
    let readingFrontier: Int
    let finishedAt: Date?
}
