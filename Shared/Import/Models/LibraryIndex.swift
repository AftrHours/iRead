import Foundation

/// The books the reader can see in the library, written by the app for the Share extension, which can't read the library itself.
struct LibraryIndex: Codable, Sendable, Equatable {
    var books: [IndexedBook]
}

struct IndexedBook: Codable, Sendable, Equatable {
    /// The title the library shows, for "already in your library".
    let title: String
    let identity: BookIdentity
}
