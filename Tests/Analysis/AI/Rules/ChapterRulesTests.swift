import Foundation
import Testing
@testable import iRead

@Suite("Chapter rules: ChapterSlicer, StoryStart")
struct ChapterRulesTests {
    private func sentences(_ lengths: [Int]) -> [NumberedSentence] {
        lengths.enumerated().map { NumberedSentence(index: $0.offset, text: String(repeating: "a", count: $0.element)) }
    }

    @Test("CH-02 slices fill up to the limit")
    func slices() {
        let slices = ChapterSlicer.slices(sentences([40, 40, 40]), maxCharacters: 100)
        #expect(slices.map { $0.map(\.index) } == [[0, 1], [2]])
    }

    @Test("CH-03 a sentence over the limit gets its own slice; no sentences, no slices")
    func longAndEmpty() {
        #expect(ChapterSlicer.slices(sentences([300]), maxCharacters: 100).map { $0.map(\.index) } == [[0]])
        #expect(ChapterSlicer.slices(sentences([20, 300, 20]), maxCharacters: 100).map { $0.map(\.index) } == [[0], [1], [2]])
        #expect(ChapterSlicer.slices([], maxCharacters: 100).isEmpty)
    }

    @Test("CH-04 the story starts after the title page and the contents")
    func afterContents() {
        let titles = ["Title Page", "Contents", "Chapter One"]
        let content = BookContent.make(chapters: [
            ["A Small Book", "by Someone"],
            titles,
            ["It was a cold morning.", "Anna woke early."]
        ], titles: titles)
        #expect(StoryStart.firstStoryChapter(in: content) == 2)
    }

    @Test("CH-05 with no contents chapter the story starts at chapter 1")
    func noContents() {
        let content = BookContent.make(chapters: [["A Small Book"], ["It was a cold morning.", "Anna woke early.", "She went out."]])
        #expect(StoryStart.firstStoryChapter(in: content) == 0)
    }
}
