import Foundation

/// One book in a Gutendex search result (gutendex.com/books/?search=…). Only the fields the app reads.
struct GutendexBook: Decodable, Sendable, Equatable {
    struct Person: Decodable, Sendable, Equatable {
        /// "Last, First", as Gutendex writes it.
        let name: String
    }

    let id: Int
    let title: String
    let authors: [Person]
    /// Media type → download URL.
    let formats: [String: String]
}
