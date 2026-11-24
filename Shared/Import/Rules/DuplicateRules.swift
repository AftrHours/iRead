import Foundation

/// The same book, as the reader sees it: the same Project Gutenberg ebook, the same work (title and author), or the same text.
enum DuplicateRules {
    static func checkDuplicates(of identity: BookIdentity, in books: [IndexedBook]) -> IndexedBook? {
        books.first { isSame(identity, $0.identity) }
    }

    private static func isSame(_ a: BookIdentity, _ b: BookIdentity) -> Bool {
        if let first = a.gutenbergNumber, let second = b.gutenbergNumber, first == second { return true }
        if let first = a.fingerprint, let second = b.fingerprint, first == second { return true }
        return !EditionMatcher.key(a.title).isEmpty
            && EditionMatcher.titlesMatch(a.title, b.title)
            && EditionMatcher.authorsMatch(a.author, b.author)
    }
}
