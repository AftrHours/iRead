import Foundation

protocol EPUBParseSvc: Sendable {
    func parse(_ url: URL) async throws -> BookContent
}
