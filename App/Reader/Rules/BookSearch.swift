import Foundation

enum BookSearch {
    static func matches(of query: String, in content: BookContent) -> [(position: ReadingPosition, length: Int, snippet: String)] {
        content.sentences.compactMap { sentence in
            let paragraph = content.paragraphs[sentence.paragraph]
            let range = NSRange(location: paragraph.range.location + sentence.range.location, length: sentence.range.length)
            let text = (content.chapters[paragraph.chapterIndex].text as NSString).substring(with: range)
            guard let match = text.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) else { return nil }
            let matchRange = NSRange(match, in: text)
            let charOffset = sentence.range.location + matchRange.location
            return (ReadingPosition(paragraph: sentence.paragraph, charOffset: charOffset), matchRange.length, text)
        }
    }
}
