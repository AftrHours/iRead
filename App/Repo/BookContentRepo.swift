import Foundation

protocol BookContentRepo: Sendable {
    func content(for bookID: UUID) async throws -> BookContent
}
