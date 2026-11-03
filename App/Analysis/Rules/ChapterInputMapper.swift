import Foundation
import UnderlineEngine

/// One chapter of `BookContent` in the shape UnderlineEngine takes. Indexes stay global.
enum ChapterInputMapper {
    static func input(chapter chapterIndex: Int, in content: BookContent) -> ChapterInput {
        let chapter = content.chapters[chapterIndex]
        let text = chapter.text as NSString
        let paragraphs = chapter.paragraphs.map { ParagraphInput(index: $0, text: text.substring(with: content.paragraphs[$0].range)) }
        let sentences = content.sentences.enumerated()
            .filter { chapter.paragraphs.contains($0.element.paragraph) }
            .map { SentenceInput(index: $0.offset, paragraph: $0.element.paragraph, range: $0.element.range) }
        return ChapterInput(chapterIndex: chapterIndex, paragraphs: paragraphs, sentences: sentences)
    }
}
