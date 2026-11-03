import Foundation
import UnderlineEngine

/// Turns one chapter of the app's BookContent into UnderlineEngine's input. Both use the same global paragraph
/// and sentence indexes and UTF-16 ranges, so nothing is converted, only copied.
enum ChapterInputMapper {
    static func input(chapter chapterIndex: Int, in content: BookContent) -> ChapterInput {
        let chapter = content.chapters[chapterIndex]
        let paragraphs = chapter.paragraphs.map { index in
            ParagraphInput(index: index, text: (chapter.text as NSString).substring(with: content.paragraphs[index].range))
        }
        let sentences = content.sentences.indices.compactMap { index -> SentenceInput? in
            let sentence = content.sentences[index]
            guard chapter.paragraphs.contains(sentence.paragraph) else { return nil }
            return SentenceInput(index: index, paragraph: sentence.paragraph, range: sentence.range)
        }
        return ChapterInput(chapterIndex: chapterIndex, paragraphs: paragraphs, sentences: sentences)
    }

    /// The global index of the first sentence on a page, so underlining starts where the reader is.
    static func firstSentence(on page: Page, in content: BookContent) -> Int {
        content.sentences.firstIndex { sentence in
            let paragraph = content.paragraphs[sentence.paragraph]
            return paragraph.chapterIndex == page.chapterIndex && paragraph.range.location + NSMaxRange(sentence.range) > page.range.location
        } ?? 0
    }
}
