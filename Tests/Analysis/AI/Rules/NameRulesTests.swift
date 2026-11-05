import Foundation
import Testing
@testable import iRead

/// The word tags are written out by hand, the way WordTagSvc gives them with Apple's English models.
/// A fresh simulator (like Xcode Cloud's) may not have those models, and these tests check the rules, not the tagger.
@Suite("Name rules: NameKey, MentionFinder, NameVocabularyBuilder")
struct NameRulesTests {
    /// One word of a sentence: its text, word class and name type ("PersonalName" or nil).
    private typealias Word = (text: String, lexicalClass: String, name: String?)

    private func tagged(_ sentences: [(text: String, words: [Word])]) -> ([NumberedSentence], SentenceTags) {
        let numbered = sentences.enumerated().map { NumberedSentence(index: $0.offset, text: $0.element.text) }
        let tokens = sentences.map { sentence in
            var searchFrom = 0
            return sentence.words.map { word in
                let text = sentence.text as NSString
                let range = text.range(of: word.text, range: NSRange(location: searchFrom, length: text.length - searchFrom))
                searchFrom = NSMaxRange(range)
                return Token(text: word.text, lexicalClass: word.lexicalClass, name: word.name, lemma: word.text.lowercased(),
                             start: range.location, length: range.length)
            }
        }
        return (numbered, SentenceTags(tokens: tokens))
    }

    private func mentions(in sentences: [(text: String, words: [Word])]) -> [ResolvedMention] {
        let (numbered, tags) = tagged(sentences)
        return MentionFinder.mentions(in: numbered, tags: tags, names: [])
    }

    @Test("CH-01 name keys ignore case, dots and extra spaces")
    func nameKey() {
        #expect(["Mr. Darcy", "MR  DARCY", "mr darcy"].map(NameKey.of) == ["mr darcy", "mr darcy", "mr darcy"])
    }

    @Test("CH-06 a title joins the name after it, and is never a mention alone")
    func titledName() {
        let found = mentions(in: [
            ("Mr. Darcy looked at Elizabeth.", [("Mr", "Noun", "PersonalName"), ("Darcy", "Noun", "PersonalName"), ("looked", "Verb", nil),
                                                ("at", "Preposition", nil), ("Elizabeth", "Noun", "PersonalName")]),
            // Tagged as a name on purpose: a title on its own must still not count.
            ("They waited for the Mr. at the door.", [("They", "Pronoun", nil), ("waited", "Verb", nil), ("for", "Preposition", nil),
                                                      ("the", "Determiner", nil), ("Mr", "Noun", "PersonalName"), ("at", "Preposition", nil),
                                                      ("the", "Determiner", nil), ("door", "Noun", nil)])
        ])
        #expect(found.filter { $0.sentence == 0 && $0.form == .name }.map(\.head) == ["mr darcy", "elizabeth"])
        #expect(!found.contains { $0.head == "mr" })
    }

    @Test("CH-07 group words aren't characters; a person description is found")
    func descriptions() {
        // "Everyone" is tagged as a name on purpose: group words are never characters.
        let found = mentions(in: [
            ("Everyone saw the tall girl.", [("Everyone", "Noun", "PersonalName"), ("saw", "Verb", nil), ("the", "Determiner", nil),
                                             ("tall", "Adjective", nil), ("girl", "Noun", nil)])
        ])
        #expect(!found.contains { $0.text == "Everyone" })
        #expect(found.filter { $0.form == .description }.map(\.head) == ["girl"])
    }

    @Test("CH-08 a word mostly written in lower case isn't a known name")
    func lowercaseWord() {
        let name: (String, String) -> (text: String, words: [Word]) = { first, name in
            ("\(first) \(name) came home.", [(first, "Adverb", nil), (name, "Noun", "PersonalName"), ("came", "Verb", nil), ("home", "Noun", nil)])
        }
        let lowercase: (text: String, words: [Word]) = ("I will go now.", [("I", "Pronoun", nil), ("will", "Verb", nil), ("go", "Verb", nil),
                                                                          ("now", "Adverb", nil)])
        let (sentences, tags) = tagged([name("Then", "Will"), name("And", "Will"), name("Then", "Anna"), name("And", "Anna")]
            + Array(repeating: lowercase, count: 20))
        let vocabulary = NameVocabularyBuilder.build(sentences: sentences, tags: tags)
        #expect(!vocabulary.names.contains("will"))
        #expect(vocabulary.names.contains("anna"))
    }
}
