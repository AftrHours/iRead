import Foundation

enum BookSearch {
    typealias Match = (position: ReadingPosition, length: Int, snippet: String)

    /// Every sentence that contains the query, ignoring case and accents. `isCancelled` is asked before each sentence,
    /// so a caller can stop a long search; a stopped search finds nothing.
    static func matches(of query: String, in content: BookContent, isCancelled: () -> Bool = { false }) -> [Match] {
        var matches: [Match] = []
        for sentence in content.sentences {
            if isCancelled() { return [] }
            let paragraph = content.paragraphs[sentence.paragraph]
            let range = NSRange(location: paragraph.range.location + sentence.range.location, length: sentence.range.length)
            let text = (content.chapters[paragraph.chapterIndex].text as NSString).substring(with: range)
            guard let match = text.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) else { continue }
            let matchRange = NSRange(match, in: text)
            let charOffset = sentence.range.location + matchRange.location
            matches.append((ReadingPosition(paragraph: sentence.paragraph, charOffset: charOffset), matchRange.length, text))
        }
        return matches
    }
}
