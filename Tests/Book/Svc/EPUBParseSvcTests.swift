import Foundation
import Testing
@testable import iRead

@Suite("EPUBParseSvc")
struct EPUBParseSvcTests {
    private let svc = EPUBParseSvcEPUBKit()

    /// The paragraphs written into minimal.epub by make-fixtures.sh.
    private let minimalParagraphs = [
        [
            "Anna opened the door. The hall was dark and cold.",
            "Mr. Darcy bowed. She left the room without a word.",
            "Outside, the rain kept falling on the quiet street."
        ],
        [
            "Morning came slowly over the hills.",
            "Anna found the letter under the old clock. It was addressed to her.",
            "She read it twice, then put it in the fire."
        ]
    ]

    @Test("BK-01 minimal.epub has 2 chapters of 3 paragraphs")
    func chaptersAndParagraphs() async throws {
        let content = try await svc.parse(Fixture.url("minimal"))
        #expect(content.chapters.map(\.title) == ["Chapter One", "Chapter Two"])
        #expect(content.chapters.map(\.paragraphs) == [0..<3, 3..<6])
        #expect(content.paragraphs.map(\.chapterIndex) == [0, 0, 0, 1, 1, 1])
    }

    @Test("BK-02 paragraph ranges match the source text, joined by one newline")
    func paragraphRanges() async throws {
        let content = try await svc.parse(Fixture.url("minimal"))
        for (chapterIndex, chapter) in content.chapters.enumerated() {
            #expect(chapter.text == minimalParagraphs[chapterIndex].joined(separator: "\n"))
            for (offset, index) in chapter.paragraphs.enumerated() {
                #expect(content.text(ofParagraph: index) == minimalParagraphs[chapterIndex][offset])
            }
        }
    }

    @Test("BK-03 every sentence sits inside its paragraph, with no spaces around it")
    func sentenceRanges() async throws {
        let parsed = try await svc.parse(Fixture.url("minimal"))
        let spaced = BookContent.make(chapters: [["  Hello there.   General Kenobi!  ", "\tOne. Two.\u{00A0}"]])
        for content in [parsed, spaced] {
            #expect(!content.sentences.isEmpty)
            for (index, sentence) in content.sentences.enumerated() {
                let paragraph = content.paragraphs[sentence.paragraph]
                #expect(sentence.range.location >= 0)
                #expect(NSMaxRange(sentence.range) <= paragraph.range.length)
                let text = content.text(ofSentence: index)
                #expect(text == text.trimmingCharacters(in: .whitespacesAndNewlines))
                #expect(!text.isEmpty)
            }
        }
    }

    @Test("BK-04 a title like Mr. doesn't end a sentence", arguments: [" ", "\u{00A0}"])
    func titleAbbreviation(space: String) {
        let paragraph = "Mr.\(space)Darcy bowed. She left."
        let content = BookContent.make(chapters: [[paragraph]])
        #expect(content.sentences.count == 2)
        #expect((0..<content.sentences.count).map(content.text(ofSentence:)) == ["Mr.\(space)Darcy bowed.", "She left."])
    }

    @Test("BK-05 no-chapters.epub can't be read")
    func noChapters() async throws {
        let url = try Fixture.url("no-chapters")
        await #expect(throws: ContentError.unreadable) { try await svc.parse(url) }
    }

    @Test("BK-05 corrupt.epub can't be read")
    func corrupt() async throws {
        let url = try Fixture.url("corrupt")
        await #expect(throws: ContentError.unreadable) { try await svc.parse(url) }
        #expect(throws: ContentError.unreadable) { try svc.metadata(from: url) }
        #expect(throws: ContentError.unreadable) { try svc.cover(from: url) }
    }

    @Test("BK-06 emoji and accents keep UTF-16 ranges lined up")
    func emojiAndAccents() {
        let paragraphs = ["Café 😀 naïve, señor. 👩‍👩‍👧 Zoë smiled.", "Ünder the bridge. Done."]
        let content = BookContent.make(chapters: [paragraphs])
        #expect(content.text(ofParagraph: 0) == paragraphs[0])
        #expect(content.text(ofParagraph: 1) == paragraphs[1])
        #expect(content.paragraphs[1].range.location == paragraphs[0].utf16.count + 1)
        #expect((0..<content.sentences.count).map(content.text(ofSentence:))
            == ["Café 😀 naïve, señor.", "👩‍👩‍👧 Zoë smiled.", "Ünder the bridge.", "Done."])
    }

    @Test("BK-07 metadata and covers from EPUB 2, EPUB 3 and no cover")
    func metadataAndCover() throws {
        let pngSignature = Data([0x89, 0x50, 0x4E, 0x47])
        for name in ["epub2-cover", "epub3-cover"] {
            let url = try Fixture.url(name)
            let metadata = try svc.metadata(from: url)
            #expect(metadata.title == (name == "epub2-cover" ? "EPUB 2 Cover" : "EPUB 3 Cover"))
            #expect(metadata.author == "Cover Author")
            #expect(try svc.cover(from: url)?.prefix(4) == pngSignature, "\(name)")
        }
        #expect(try svc.cover(from: Fixture.url("minimal")) == nil)
    }

    /// Chapter counts of the bundled books. If the parser changes them on purpose, bump `parserVersion`
    /// in EPUBParseSvc (stored analyses and underlines depend on it) and update this list.
    private static let sampleChapterCounts = [
        "little-women": 52,
        "anne-of-green-gables": 42,
        "moby-dick": 145,
        "pride-and-prejudice": 466,
        "the-adventures-of-sherlock-holmes": 18
    ]

    @Test("BK-13 the bundled books parse into the stored chapter counts", .tags(.golden))
    func bundledSamples() async throws {
        var counts: [String: Int] = [:]
        for sample in BookRecord.samples {
            let url = try #require(Bundle.main.url(forResource: sample.fileName, withExtension: "epub"))
            counts[sample.fileName] = try await svc.parse(url).chapters.count
        }
        #expect(counts == Self.sampleChapterCounts)
    }
}
