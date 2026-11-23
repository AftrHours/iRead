import Foundation
import Testing
@testable import iRead

@Suite("CharacterRules")
struct CharacterRulesTests {
    private func mention(_ name: String, paragraph: Int, at offset: Int = 0) -> NameMention {
        NameMention(name: name, position: ReadingPosition(paragraph: paragraph, charOffset: offset))
    }

    private func underline(_ id: String, phrase: String, paragraph: Int, passage: String, passageParagraph: Int,
                           kind: String = "action") -> SavedUnderline {
        SavedUnderline(id: id, sentence: paragraph, paragraph: paragraph, range: NSRange(location: 0, length: phrase.utf16.count),
                       text: phrase, kind: kind, decidedBy: "rules",
                       reference: ContextPassage(sentence: passageParagraph, paragraph: passageParagraph,
                                                 range: NSRange(location: 0, length: passage.utf16.count), text: passage))
    }

    @Test("CH-01 nicknames and full names are one character, named by the most used then the longest, latest mentioned first")
    func joinsNames() {
        let mentions = [
            mention("Jo", paragraph: 1), mention("Jo", paragraph: 2), mention("Josephine March", paragraph: 3),
            mention("Josephine March", paragraph: 4), mention("Josephine March", paragraph: 5), mention("Jo", paragraph: 6),
            mention("Jo", paragraph: 7),
            mention("Laurie", paragraph: 8), mention("Laurie", paragraph: 9), mention("Laurie", paragraph: 10),
            mention("Laurence", paragraph: 11), mention("Laurence", paragraph: 12), mention("Laurence", paragraph: 13),
            mention("Laurie", paragraph: 14),
            mention("Beth", paragraph: 2), mention("Beth", paragraph: 3), mention("Beth", paragraph: 4), mention("Beth March", paragraph: 4),
            mention("Beth March", paragraph: 5), mention("Beth March", paragraph: 5)
        ]
        let characters = CharacterRules.characters(from: mentions, underlines: [])
        #expect(characters.map(\.name) == ["Laurie/Laurence", "Jo/Josephine March", "Beth March"])
        #expect(Set(characters[1].names) == ["Jo", "Josephine March"])
    }

    @Test("CH-02 names mentioned fewer than three times, words that aren't names and headings are left out; titled names stay apart")
    func leavesOutNoise() {
        let mentions = [
            mention("Hannah", paragraph: 1), mention("Hannah", paragraph: 2),
            mention("Christmas", paragraph: 1), mention("Christmas", paragraph: 2), mention("Christmas", paragraph: 3),
            mention("CHAPTER", paragraph: 1), mention("CHAPTER", paragraph: 2), mention("CHAPTER", paragraph: 3),
            mention("I’m", paragraph: 1), mention("I’m", paragraph: 2), mention("I’m", paragraph: 3),
            mention("Father", paragraph: 1), mention("Father", paragraph: 2), mention("Father", paragraph: 3),
            mention("Laurie", paragraph: 1), mention("Laurie", paragraph: 2), mention("Laurie", paragraph: 3),
            mention("Mr. Laurence", paragraph: 4), mention("Mr. Laurence", paragraph: 5), mention("Mr. Laurence", paragraph: 6),
            mention("Meg’s", paragraph: 1), mention("Meg", paragraph: 2), mention("Meg", paragraph: 3)
        ]
        let names = CharacterRules.characters(from: mentions, underlines: []).map(\.name)
        #expect(Set(names) == ["Laurie", "Mr. Laurence", "Meg"])
    }

    @Test("CH-03 the describing passage: the name in the passage beats a name nearby, a tie goes to the latest, none leaves it empty")
    func picksPassage() throws {
        var mentions = (1...3).map { mention("Laurie", paragraph: $0) }
        mentions += (1...3).map { mention("Amy", paragraph: 20 + $0) }
        // Laurie is named in paragraph 2, so an underline there links to him, but the passage that names him wins.
        let nearby = underline("nearby", phrase: "a curly black head", paragraph: 2, passage: "Curly black hair, brown skin.",
                               passageParagraph: 0, kind: "thing")
        let named = underline("named", phrase: "the boy at the window", paragraph: 9, passage: "So I made them say Laurie instead.",
                              passageParagraph: 5)
        let namedEarlier = underline("namedEarlier", phrase: "his old name", paragraph: 7, passage: "Laurie laughed.",
                                     passageParagraph: 4)
        let characters = CharacterRules.characters(from: mentions, underlines: [nearby, namedEarlier, named])
        let laurie = try #require(characters.first { $0.name == "Laurie" })
        #expect(laurie.underlineID == "named")
        #expect(laurie.passage == "So I made them say Laurie instead.")
        let amy = characters.first { $0.name == "Amy" }
        #expect(amy?.underlineID == nil)
        #expect(amy?.passage == nil)
    }

    @Test("CH-04 search finds any of a character's names, ignoring case, and forgives one typo in a longer search")
    func search() {
        let laurie = BookCharacter(name: "Laurie/Laurence", names: ["Laurie", "Laurence"], underlineID: nil, passage: nil)
        #expect(CharacterRules.matches(laurie, query: "laur"))
        #expect(CharacterRules.matches(laurie, query: "LAURENCE"))
        #expect(CharacterRules.matches(laurie, query: "Lauire"))
        #expect(CharacterRules.matches(laurie, query: ""))
        #expect(!CharacterRules.matches(laurie, query: "Haymitch"))
        #expect(!CharacterRules.matches(laurie, query: "Lx"))
    }
}
