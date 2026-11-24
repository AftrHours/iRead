import Foundation

/// The Project Gutenberg ebook number in an EPUB's `dc:identifier` or `dc:source`.
enum GutenbergNumber {
    static func from(identifiers: [String]) -> Int? {
        for identifier in identifiers {
            if let match = identifier.firstMatch(of: /gutenberg\.org\/(?:ebooks\/|files\/)?(\d+)/), let number = Int(match.1) {
                return number
            }
        }
        return nil
    }

    /// The number in an OPDS search entry's id ("https://www.gutenberg.org/ebooks/15489.opds"). nil for entries that aren't books.
    static func opdsEntry(_ id: String) -> Int? {
        id.firstMatch(of: /\/ebooks\/(\d+)\.opds$/).flatMap { Int($0.1) }
    }
}
