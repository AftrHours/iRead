import Foundation
import Testing
@testable import iRead

@Suite("BookSearch")
struct BookSearchTests {
    @Test("RD-13 search ignores case and accents, and the snippet is the sentence")
    func caseAndAccents() {
        let content = BookContent.make(chapters: [["We met at the Café on Monday. It rained.", "THE CAFE WAS CLOSED. Nobody came."]])
        let matches = BookSearch.matches(of: "cafe", in: content)
        #expect(matches.map(\.snippet) == ["We met at the Café on Monday.", "THE CAFE WAS CLOSED."])
        #expect(matches.map(\.length) == [4, 4])
    }

    @Test("RD-14 a match mid-sentence gives its paragraph, offset and length")
    func position() throws {
        var paragraphs = (0..<7).map { "Paragraph \($0) says nothing much." }
        paragraphs.append("First words here. Then the zebra ran away.")
        let content = BookContent.make(chapters: [paragraphs])
        let match = try #require(BookSearch.matches(of: "zebra", in: content).first)
        let offset = (paragraphs[7] as NSString).range(of: "zebra").location
        #expect(match.position == ReadingPosition(paragraph: 7, charOffset: offset))
        #expect(match.length == 5)
    }

    @Test("RD-15 no match and an empty query both find nothing")
    func nothingFound() {
        let content = BookContent.make(chapters: [["Some text here."]])
        #expect(BookSearch.matches(of: "zebra", in: content).isEmpty)
        #expect(BookSearch.matches(of: "", in: content).isEmpty)
    }
}
