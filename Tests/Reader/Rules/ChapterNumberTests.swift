import Testing
@testable import iRead

@Suite("ChapterNumber")
struct ChapterNumberTests {
    @Test("reads the number after 'Chapter', spelled, as digits or as a Roman numeral", arguments: [
        ("CHAPTER TWO A MERRY CHRISTMAS", 2),
        ("CHAPTER TWENTY-ONE LAURIE MAKES MISCHIEF, AND JO MAKES PEACE", 21),
        ("Chapter 12. Snow", 12),
        ("CHAPTER XLIV", 44),
        ("Chapter I. Loomings.", 1)
    ])
    func afterChapter(title: String, expected: Int) {
        #expect(ChapterNumber.from(title: title) == expected)
    }

    @Test("reads a title that starts with a Roman numeral or digits", arguments: [
        ("II. The Red-Headed League", 2),
        ("XII. The Adventure of the Copper Beeches", 12),
        ("3 The Gift", 3)
    ])
    func leadingNumber(title: String, expected: Int) {
        #expect(ChapterNumber.from(title: title) == expected)
    }

    @Test("finds no number in front matter, or in titles that only start with a word number or a Roman-looking word",
          arguments: ["Contents", "Preface", "Little Women", "One Fine Day", "Mix and Match", "I Remember", ""])
    func noNumber(title: String) {
        #expect(ChapterNumber.from(title: title) == nil)
    }

    @MainActor
    @Test("the card shows 'Chapter N • Page P', or the section's own title when it has no number")
    func cardLocation() {
        #expect(ReferenceVM.location(chapterTitle: "CHAPTER TWO A MERRY CHRISTMAS", page: 19) == "Chapter 2 • Page 19")
        #expect(ReferenceVM.location(chapterTitle: "Contents", page: 3) == "Contents • Page 3")
    }
}
