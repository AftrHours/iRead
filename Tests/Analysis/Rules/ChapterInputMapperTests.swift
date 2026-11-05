import Foundation
import Testing
@testable import iRead

@Suite("ChapterInputMapper")
struct ChapterInputMapperTests {
    private let content = BookContent.make(chapters: [
        ["The first chapter. It has two sentences."],
        ["Chapter two begins. It goes on.", "A second paragraph here."],
        ["The last chapter."]
    ])

    @Test("AN-01 a chapter's input keeps only its own paragraphs and sentences, with global indexes")
    func input() {
        let input = ChapterInputMapper.input(chapter: 1, in: content)
        let paragraphs = Array(content.chapters[1].paragraphs)
        let sentences = content.sentences.indices.filter { paragraphs.contains(content.sentences[$0].paragraph) }
        #expect(input.chapterIndex == 1)
        #expect(input.paragraphs.map(\.index) == paragraphs)
        #expect(input.paragraphs.map(\.text) == paragraphs.map(content.text(ofParagraph:)))
        #expect(input.sentences.map(\.index) == sentences)
        #expect(input.sentences.map(\.paragraph) == sentences.map { content.sentences[$0].paragraph })
        for sentence in input.sentences {
            let paragraph = input.paragraphs.first { $0.index == sentence.paragraph }?.text ?? ""
            #expect((paragraph as NSString).substring(with: sentence.range) == content.text(ofSentence: sentence.index))
        }
    }

    @Test("AN-02 a page that starts mid-sentence starts underlining at that sentence")
    func firstSentence() {
        let chapterText = content.chapters[1].text as NSString
        let midSecond = chapterText.range(of: "goes on").location
        let page = Page(number: 3, chapterIndex: 1, range: NSRange(location: midSecond, length: chapterText.length - midSecond), text: "")
        let expected = content.sentences.indices.first { content.text(ofSentence: $0) == "It goes on." }
        #expect(ChapterInputMapper.firstSentence(on: page, in: content) == expected)
    }
}
