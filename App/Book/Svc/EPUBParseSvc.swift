import EPUBKit
import Foundation
import NaturalLanguage

/// Reads EPUB files with EPUBKit and turns their chapters into the app's BookContent.
struct EPUBParseSvc {
    private let reader = EPUBReader()

    func metadata(from url: URL) throws -> (title: String?, author: String?) {
        let metadata = try readingEPUB { try reader.metadata(from: url) }
        return (metadata.title, metadata.author)
    }

    /// The cover image file, found by the EPUB 3 `cover-image` property or the EPUB 2 `cover` meta tag.
    func cover(from url: URL) throws -> Data? {
        try readingEPUB { try reader.cover(from: url) }
    }

    func parse(_ url: URL) async throws -> BookContent {
        let chapters = try readingEPUB { try reader.chapters(from: url) }
        guard !chapters.isEmpty else { throw ContentError.unreadable }
        return content(of: chapters)
    }

    /// EPUBKit reports a broken file as its own error; the rest of the app expects ContentError.
    private func readingEPUB<Result>(_ read: () throws -> Result) throws -> Result {
        do {
            return try read()
        } catch EPUBError.unreadable {
            throw ContentError.unreadable
        }
    }

    private func content(of rawChapters: [EPUBChapter]) -> BookContent {
        let tokenizer = NLTokenizer(unit: .sentence)
        var chapters: [Chapter] = []
        var paragraphs: [Paragraph] = []
        var sentences: [Sentence] = []
        for (chapterIndex, rawChapter) in rawChapters.enumerated() {
            let firstParagraph = paragraphs.count
            var location = 0
            for text in rawChapter.paragraphs {
                let length = text.utf16.count
                sentences += sentenceRanges(in: text, tokenizer: tokenizer).map { Sentence(paragraph: paragraphs.count, range: $0) }
                paragraphs.append(Paragraph(
                    chapterIndex: chapterIndex,
                    range: NSRange(location: location, length: length),
                    wordCount: text.split(whereSeparator: \.isWhitespace).count
                ))
                location += length + 1
            }
            chapters.append(Chapter(
                title: rawChapter.title,
                text: rawChapter.paragraphs.joined(separator: "\n"),
                paragraphs: firstParagraph..<paragraphs.count
            ))
        }
        return BookContent(chapters: chapters, paragraphs: paragraphs, sentences: sentences, parserVersion: 1)
    }

    private func sentenceRanges(in text: String, tokenizer: NLTokenizer) -> [NSRange] {
        // Ebooks often put a no-break space after "Mr." or "Dr.", which the tokenizer reads as a sentence end.
        // A copy with plain spaces has the same UTF-16 length, so its ranges still match the original text.
        let plain = text.replacingOccurrences(of: "\u{00A0}", with: " ")
        tokenizer.string = plain
        return tokenizer.tokens(for: plain.startIndex..<plain.endIndex).compactMap { tokenRange in
            let range = NSRange(tokenRange, in: plain)
            let token = (text as NSString).substring(with: range)
            let sentence = token.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !sentence.isEmpty else { return nil }
            let leadingSpaces = token.prefix(while: \.isWhitespace).utf16.count
            return NSRange(location: range.location + leadingSpaces, length: sentence.utf16.count)
        }
    }
}
