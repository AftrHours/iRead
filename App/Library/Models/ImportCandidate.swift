import Foundation

/// An EPUB about to be imported: what the library will show, and what tells it apart from the books already there.
struct ImportCandidate: Sendable {
    let title: String
    let author: String
    let identity: BookIdentity
}
