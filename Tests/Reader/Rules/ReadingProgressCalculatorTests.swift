import Foundation
import Testing
@testable import iRead

@Suite("ReadingProgressCalculator")
struct ReadingProgressCalculatorTests {
    /// 15 words: 3, 2, 4, 2 in chapter 1 and 3, 1 in chapter 2.
    private let content = BookContent.make(chapters: [
        ["One two three.", "Four five.", "Six seven eight nine.", "Ten eleven."],
        ["Twelve thirteen fourteen.", "Fifteen."]
    ])
    private let date = Date(timeIntervalSince1970: 1_700_000_000)

    private func page(chapter: Int, from location: Int, length: Int) -> Page {
        Page(number: 1, chapterIndex: chapter, range: NSRange(location: location, length: length), text: "")
    }

    @Test("PR-01 the first page is 0%, at (0, 0), not finished")
    func firstPage() {
        let progress = ReadingProgressCalculator.progress(on: page(chapter: 0, from: 0, length: 10), in: content, bookID: UUID(), at: date)
        #expect(progress.progress == 0)
        #expect(progress.position == ReadingPosition(paragraph: 0, charOffset: 0))
        #expect(progress.finishedAt == nil)
    }

    @Test("PR-02 progress is the words before the page over all words")
    func wordsBefore() {
        let start = content.paragraphs[3].range.location
        let progress = ReadingProgressCalculator.progress(on: page(chapter: 0, from: start, length: 5), in: content, bookID: UUID(), at: date)
        #expect(progress.progress == 9.0 / 15.0)
        #expect(progress.position == ReadingPosition(paragraph: 3, charOffset: 0))
    }

    @Test("PR-03 the last page of the last chapter finishes the book")
    func lastPage() {
        let length = content.chapters[1].text.utf16.count
        let progress = ReadingProgressCalculator.progress(on: page(chapter: 1, from: length - 5, length: 5), in: content, bookID: UUID(), at: date)
        #expect(progress.finishedAt == date)
    }

    @Test("PR-04 99% read finishes the book even before the last page")
    func almostDone() {
        let long = Array(repeating: "word", count: 300).joined(separator: " ")
        let content = BookContent.make(chapters: [[long], ["Fin end."]])
        let progress = ReadingProgressCalculator.progress(on: page(chapter: 1, from: 0, length: 2), in: content, bookID: UUID(), at: date)
        #expect(progress.progress >= 0.99)
        #expect(progress.finishedAt == date)
    }

    @Test("PR-05 merging keeps the furthest frontier and the new position")
    func frontierKept() {
        let previous = ReadingProgress.make(paragraph: 9, readingFrontier: 40)
        let new = ReadingProgress.make(paragraph: 4, charOffset: 2, readingFrontier: 25)
        let merged = ReadingProgressCalculator.merged(new, after: previous)
        #expect(merged.readingFrontier == 40)
        #expect(merged.position == new.position)
    }

    @Test("PR-06 merging keeps an earlier finishedAt")
    func finishedKept() {
        let previous = ReadingProgress.make(finishedAt: date)
        let merged = ReadingProgressCalculator.merged(.make(finishedAt: nil), after: previous)
        #expect(merged.finishedAt == date)
    }

    @Test("PR-07 a chapter offset maps to the right paragraph and offset")
    func position() {
        let firstLength = content.paragraphs[0].range.length
        #expect(ReadingProgressCalculator.position(chapterIndex: 0, offset: 0, in: content) == ReadingPosition(paragraph: 0, charOffset: 0))
        #expect(ReadingProgressCalculator.position(chapterIndex: 0, offset: content.paragraphs[2].range.location, in: content)
            == ReadingPosition(paragraph: 2, charOffset: 0))
        // The "\n" after paragraph 0 still belongs to paragraph 0.
        #expect(ReadingProgressCalculator.position(chapterIndex: 0, offset: firstLength, in: content)
            == ReadingPosition(paragraph: 0, charOffset: firstLength))
        #expect(ReadingProgressCalculator.position(chapterIndex: 1, offset: 0, in: content) == ReadingPosition(paragraph: 4, charOffset: 0))
        for offset in 0...content.chapters[0].text.utf16.count {
            #expect(ReadingProgressCalculator.position(chapterIndex: 0, offset: offset, in: content).charOffset >= 0)
        }
    }
}
