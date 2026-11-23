import Foundation
import UnderlineKit

/// The book as UnderlineEngine reads it. Both use the same global paragraph and sentence indexes and UTF-16 ranges, so
/// nothing is converted, only copied, and only for the chapters the engine asks for.
extension BookContent: BookSource {
    var id: String { fingerprint }
    var chapterCount: Int { chapters.count }

    func chapterText(_ index: Int) -> ChapterText {
        let chapter = chapters[index]
        let paragraphTexts = chapter.paragraphs.map { paragraph in
            ChapterText.Paragraph(index: paragraph, text: (chapter.text as NSString).substring(with: paragraphs[paragraph].range))
        }
        let sentenceRanges = sentences.indices.compactMap { sentence -> ChapterText.Sentence? in
            let found = sentences[sentence]
            guard chapter.paragraphs.contains(found.paragraph) else { return nil }
            return ChapterText.Sentence(index: sentence, paragraph: found.paragraph, range: found.range)
        }
        return ChapterText(paragraphs: paragraphTexts, sentences: sentenceRanges)
    }
}

enum ChapterInputMapper {
    /// The global index of the first sentence on a page, so underlining starts where the reader is.
    static func firstSentence(on page: Page, in content: BookContent) -> Int {
        content.sentences.firstIndex { sentence in
            let paragraph = content.paragraphs[sentence.paragraph]
            return paragraph.chapterIndex == page.chapterIndex && paragraph.range.location + NSMaxRange(sentence.range) > page.range.location
        } ?? 0
    }
}
