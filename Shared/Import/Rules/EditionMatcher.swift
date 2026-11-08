import Foundation

/// Matches the book a reader shared with a Project Gutenberg edition, by title and author.
enum EditionMatcher {
    /// Lowercased, with every character that isn't a letter or digit turned into a space, and runs of spaces collapsed,
    /// so "Moby-Dick; Or, The Whale" and "Moby Dick" compare word by word.
    static func key(_ text: String) -> String {
        let spaced = String(text.lowercased().map { $0.isLetter || $0.isNumber ? $0 : " " })
        return spaced.split(separator: " ").joined(separator: " ")
    }

    /// "Melville, Herman" → "Herman Melville". Other names are kept.
    static func displayName(_ gutendexName: String) -> String {
        let pieces = gutendexName.components(separatedBy: ", ")
        return pieces.count == 2 ? "\(pieces[1]) \(pieces[0])" : gutendexName
    }

    /// Equal, or one is the other followed by more words (a subtitle).
    static func titlesMatch(_ a: String, _ b: String) -> Bool {
        let first = key(a)
        let second = key(b)
        return first == second || first.hasPrefix(second + " ") || second.hasPrefix(first + " ")
    }

    /// True when either is empty (an unknown author doesn't block a match), or one name's last word is among the other's words.
    static func authorsMatch(_ a: String, _ b: String) -> Bool {
        let first = key(a).split(separator: " ")
        let second = key(b).split(separator: " ")
        guard let firstLast = first.last, let secondLast = second.last else { return true }
        return second.contains(firstLast) || first.contains(secondLast)
    }

    /// Gutendex finds a book only when every query word is in its title or author, so the query is the plain main title
    /// (before ":", ";" or "(", which start subtitles and edition notes like "(Illustrated)") and the author's last name.
    static func searchQuery(title: String, author: String) -> String {
        let base = titleQuery(title)
        guard let lastName = key(author).split(separator: " ").last else { return base }
        return "\(base) \(lastName)"
    }

    /// The plain main title alone, for a second search when the author's name is written differently on Gutenberg.
    static func titleQuery(_ title: String) -> String {
        let main = title.split(whereSeparator: { ":;(".contains($0) }).first.map(String.init) ?? title
        return key(main)
    }

    /// The first book with an EPUB whose title and author match. A book with no authors only matches an unknown author.
    static func bestMatch(title: String, author: String, in books: [GutendexBook]) -> GutenbergEdition? {
        for book in books {
            guard let epub = book.formats["application/epub+zip"], let epubURL = URL(string: epub),
                  titlesMatch(title, book.title) else { continue }
            let names = book.authors.map(\.name)
            let authorMatches = key(author).isEmpty || names.contains { authorsMatch(author, $0) }
            guard authorMatches else { continue }
            let display = names.first.map(displayName) ?? author
            return GutenbergEdition(number: book.id, title: book.title, author: display, epubURL: epubURL)
        }
        return nil
    }
}
