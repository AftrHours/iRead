import Foundation

protocol LibRepo: Sendable {
    func fetchBooks() async throws -> [BookRecord]
}
