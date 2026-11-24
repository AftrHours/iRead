import Foundation

enum ReadingProgressCalculator {
    static func progress(on page: Page, in content: BookContent, bookID: UUID, at date: Date) -> ReadingProgress {
        let start = position(chapterIndex: page.chapterIndex, offset: page.range.location, in: content)
        let pageEnd = position(chapterIndex: page.chapterIndex, offset: NSMaxRange(page.range), in: content)
        let lastVisibleSentence = content.sentences.lastIndex {
            ReadingPosition(paragraph: $0.paragraph, charOffset: $0.range.location) < pageEnd
        } ?? 0
        let wordsBefore = content.paragraphs[..<start.paragraph].reduce(0) { $0 + $1.wordCount }
        let totalWords = content.paragraphs.reduce(0) { $0 + $1.wordCount }
        let progress = Double(wordsBefore) / Double(totalWords)
        let isLastPage = page.chapterIndex == content.chapters.count - 1
            && NSMaxRange(page.range) == content.chapters[page.chapterIndex].text.utf16.count
        return ReadingProgress(
            bookID: bookID,
            position: start,
            chapterIndex: page.chapterIndex,
            progress: progress,
            lastReadAt: date,
            readingFrontier: lastVisibleSentence,
            finishedAt: isLastPage || progress >= 0.99 ? date : nil
        )
    }

    static func merged(_ progress: ReadingProgress, after previous: ReadingProgress?) -> ReadingProgress {
        ReadingProgress(
            bookID: progress.bookID,
            position: progress.position,
            chapterIndex: progress.chapterIndex,
            progress: progress.progress,
            lastReadAt: progress.lastReadAt,
            readingFrontier: max(previous?.readingFrontier ?? 0, progress.readingFrontier),
            finishedAt: previous?.finishedAt ?? progress.finishedAt
        )
    }

    static func position(chapterIndex: Int, offset: Int, in content: BookContent) -> ReadingPosition {
        let chapter = content.chapters[chapterIndex]
        let paragraph = chapter.paragraphs.last { content.paragraphs[$0].range.location <= offset } ?? chapter.paragraphs.lowerBound
        return ReadingPosition(paragraph: paragraph, charOffset: offset - content.paragraphs[paragraph].range.location)
    }
}
