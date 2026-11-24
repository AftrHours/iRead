import Foundation

/// What tells two copies of a book apart, to keep the same book out of the library twice.
struct BookIdentity: Codable, Sendable, Equatable {
    let gutenbergNumber: Int?
    let title: String
    let author: String
    /// `BookContent.fingerprint`: nil until the book has been read once (bundled samples).
    let fingerprint: String?
}
