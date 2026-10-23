import Foundation

protocol ProgRepo: Sendable {
    func progress(for bookID: UUID) async -> ReadingProgress?
    func save(_ progress: ReadingProgress) async
    func saveNow(_ progress: ReadingProgress) async
}
