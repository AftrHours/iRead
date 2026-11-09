import Foundation

/// A free Project Gutenberg EPUB of the book the reader shared.
struct GutenbergEdition: Codable, Sendable, Equatable {
    /// The Project Gutenberg ebook number, as in gutenberg.org/ebooks/<number>.
    let number: Int
    let title: String
    /// "First Last", whatever form Gutendex gave.
    let author: String
    let epubURL: URL
}
