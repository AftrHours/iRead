import Foundation
import Testing
@testable import iRead

@Suite("Name rules: NameKey, MentionFinder, NameVocabularyBuilder")
struct NameRulesTests {
    private func mentions(in texts: [String], knownNames: Set<String> = []) -> [ResolvedMention] {
        let sentences = texts.enumerated().map { NumberedSentence(index: $0.offset, text: $0.element) }
        return MentionFinder.mentions(in: sentences, tags: WordTagSvc().tag(sentences), names: knownNames)
    }

    @Test("CH-01 name keys ignore case, dots and extra spaces")
    func nameKey() {
        #expect(["Mr. Darcy", "MR  DARCY", "mr darcy"].map(NameKey.of) == ["mr darcy", "mr darcy", "mr darcy"])
    }

    @Test("CH-06 a title joins the name after it, and is never a mention alone")
    func titledName() {
        // In a book, "elizabeth" comes from NameVocabularyBuilder; in one bare sentence the word tagger can miss it.
        let found = mentions(in: ["Mr. Darcy looked at Elizabeth.", "They waited for the Mr. at the door."], knownNames: ["elizabeth"])
        #expect(found.filter { $0.sentence == 0 && $0.form == .name }.map(\.head) == ["mr darcy", "elizabeth"])
        #expect(!found.contains { $0.head == "mr" })
    }

    @Test("CH-07 group words aren't characters; a person description is found")
    func descriptions() {
        let found = mentions(in: ["Everyone saw the tall girl."])
        #expect(!found.contains { $0.text == "Everyone" })
        #expect(found.filter { $0.form == .description }.map(\.head) == ["girl"])
    }

    @Test("CH-08 a word mostly written in lower case isn't a known name")
    func lowercaseWord() {
        let texts = ["Then Will ran home.", "And Will sat down."] + Array(repeating: "I will go now.", count: 20)
        let sentences = texts.enumerated().map { NumberedSentence(index: $0.offset, text: $0.element) }
        let vocabulary = NameVocabularyBuilder.build(sentences: sentences, tags: WordTagSvc().tag(sentences))
        #expect(!vocabulary.names.contains("will"))
    }
}
