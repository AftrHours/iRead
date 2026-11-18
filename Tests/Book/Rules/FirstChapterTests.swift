import EPUBKit
import Testing
@testable import iRead

@Suite("FirstChapter")
struct FirstChapterTests {
    private func index(_ titles: [String], words: [Int]? = nil, parts: [EPUBPart?] = []) -> Int {
        FirstChapter.index(titles: titles, wordCounts: words ?? Array(repeating: 100, count: titles.count), parts: parts)
    }

    @Test("FC-01 the first chapter its file calls body matter starts the story, even before a numbered title")
    func bodyMatter() {
        #expect(index(["Welcome", "Legal Notes", "The Door", "The Letter"], parts: [.front, .front, .body, .body]) == 2)
        #expect(index(["Chapter 1 (sample)", "The Door"], parts: [nil, .body]) == 1)
    }

    @Test("FC-02 a chapter numbered 1, a prologue or a first part starts the story", arguments: [
        (["Contents", "Copyright", "Chapter 1"], 2),
        (["Contents", "Prologue", "Chapter 1"], 1),
        (["Contents", "Part One: Boyhood", "Chapter 1"], 1),
        (["Title Page", "I. Loomings."], 1),
        (["Preface", "CHAPTER I. Down the Rabbit-Hole"], 1)
    ])
    func startTitles(titles: [String], expected: Int) {
        #expect(index(titles) == expected)
    }

    @Test("FC-03 text before the table of contents, marked front matter, is skipped however long it is")
    func marked() {
        #expect(index(["Alice", "Down the Rabbit-Hole", "The Pool of Tears"], words: [3000, 400, 500], parts: [.front, nil, nil]) == 1)
        #expect(index(["Chapter 1", "Chapter 2"], parts: [.front, nil]) == 1)
    }

    @Test("FC-04 without a number or label, the first chapter that isn't front matter by title and has enough words starts it")
    func longText() {
        #expect(index(["Contents", "Copyright", "The Door"], words: [20, 50, 500]) == 2)
        #expect(index(["Contents", "Discovery"], words: [400, 400]) == 1)
        #expect(index(["Foreword", "The Door", "The Letter"], words: [900, 299, 300]) == 2)
    }

    @Test("FC-05 chapter 0 when nothing qualifies", arguments: [
        ([String](), [Int]()),
        (["Welcome"], [10]),
        (["Contents", "The Door"], [500, 100])
    ])
    func fallback(titles: [String], words: [Int]) {
        #expect(index(titles, words: words) == 0)
    }

    @Test("FC-06 a chapter marked back matter never starts the story")
    func backMatter() {
        #expect(index(["Notes", "Chapter 1"], words: [500, 500], parts: [.back, nil]) == 1)
    }
}
