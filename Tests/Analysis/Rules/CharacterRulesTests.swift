import Foundation
import Testing
@testable import iRead

@Suite("CharacterRules")
struct CharacterRulesTests {
    private func mention(_ name: String, paragraph: Int, at offset: Int = 0) -> NameMention {
        NameMention(name: name, position: ReadingPosition(paragraph: paragraph, charOffset: offset))
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
        let characters = CharacterRules.characters(from: mentions, sentences: [])
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
        let names = CharacterRules.characters(from: mentions, sentences: []).map(\.name)
        #expect(Set(names) == ["Laurie", "Mr. Laurence", "Meg"])
    }

    @Test("CH-03 each character gets the passage that describes them; one only talked about gets none")
    func picksPassage() throws {
        let sentences = [
            "“Don’t you like to dance, Miss Jo?” asked Laurie, looking as if he thought the name suited her.",
            "Laurie was a tall, handsome boy of fifteen, with curly black hair and a merry, polite manner.",
            "“Here comes Marmee,” said Laurie.",
            "Marmee is coming down the street."
        ].enumerated().map { ContextPassage(sentence: $0, paragraph: $0, range: NSRange(location: 0, length: $1.utf16.count), text: $1) }
        let mentions = [mention("Laurie", paragraph: 0, at: 60), mention("Laurie", paragraph: 1), mention("Laurie", paragraph: 2, at: 28),
                        mention("Marmee", paragraph: 2, at: 13), mention("Marmee", paragraph: 3), mention("Marmee", paragraph: 3)]
        let characters = CharacterRules.characters(from: mentions, sentences: sentences)
        let laurie = try #require(characters.first { $0.name == "Laurie" })
        #expect(laurie.passage == sentences[1])
        #expect(characters.first { $0.name == "Marmee" }?.passage == nil)
    }

    private func paragraphs(_ texts: [String]) -> [ContextPassage] {
        texts.enumerated().map { ContextPassage(sentence: $0, paragraph: $0, range: NSRange(location: 0, length: $1.utf16.count), text: $1) }
    }

    @Test("CH-05 a titled surname is its own person, a titled first name isn't (“Miss Jo”); a bare surname joins its one owner or is left out")
    func titlesAndSurnames() {
        let mentions = (1...3).flatMap { paragraph in
            [mention("Laurie", paragraph: paragraph), mention("Mr. Laurence", paragraph: paragraph), mention("Laurence", paragraph: paragraph),
             mention("Mrs. March", paragraph: paragraph), mention("Aunt March", paragraph: paragraph), mention("March", paragraph: paragraph),
             mention("Jo", paragraph: paragraph), mention("Miss Jo", paragraph: paragraph)]
        }
        let characters = CharacterRules.characters(from: mentions, sentences: [])
        #expect(Set(characters.map(\.name)) == ["Laurie", "Mr. Laurence", "Mrs. March", "Aunt March", "Jo"])
        #expect(Set(characters.first { $0.name == "Mr. Laurence" }?.names ?? []) == ["Mr. Laurence", "Laurence"])
    }

    @Test("CH-06 names the book says are one person are joined: “…so I made them say Laurie instead”")
    func namesFromTheBook() {
        let sentences = paragraphs(["“My first name is Theodore, but I don’t like it, for the fellows called me Dora, so I made them say Laurie instead.”",
                                    "Laurie laughed."])
        let mentions = [mention("Theodore", paragraph: 0)] + (1...3).map { mention("Laurie", paragraph: $0) }
        let laurie = CharacterRules.characters(from: mentions, sentences: sentences).first
        #expect(Set(laurie?.names ?? []) == ["Laurie", "Theodore"])
    }

    @Test("CH-09 ordinary words (“Good”, “Him”) and places (“Washington”) aren't characters; a person who goes places still is")
    func notPeople() {
        let sentences = paragraphs([
            "“Good gracious, Jo, him again?” said Meg.", "It was a good day, and good news came for him and for her, and him too.",
            "Father is in Washington.", "A letter came from Washington.", "She read the Washington dispatches.", "Washington was far away.",
            "Meg went to Sallie’s, and at Sallie’s house she danced.", "“Come in,” said Sallie.", "Sallie laughed."
        ])
        let mentions = [(0, "Good"), (0, "Good"), (0, "Good"), (0, "Him"), (0, "Him"), (0, "Him"),
                        (2, "Washington"), (3, "Washington"), (4, "Washington"), (5, "Washington"),
                        (6, "Sallie"), (7, "Sallie"), (8, "Sallie")].map { mention($0.1, paragraph: $0.0) }
        #expect(CharacterRules.characters(from: mentions, sentences: sentences).map(\.name) == ["Sallie"])
    }

    @Test("CH-10 groups (“Germans”, “Brookes”), parts of longer names (“Christmas Eve”) and names only in dialogue aren't characters")
    func groupsAndDialogue() {
        let sentences = paragraphs([
            "Brooke came in.", "Brooke smiled.", "The Brookes came to tea, and the Brookes stayed.",
            "A German sat by the fire.", "The Germans sang.", "Sober Germans and lively French danced.",
            "It was Christmas Eve, and on Christmas Eve they sang, and every Christmas Eve after.",
            "“Gott im Himmel, Gott help us,” he cried. “Gott knows!”"
        ])
        let mentions = [(0, "Brooke"), (1, "Brooke"), (2, "Brooke"), (2, "Brookes"), (2, "Brookes"), (4, "Brookes"),
                        (3, "German"), (4, "Germans"), (5, "Germans"), (5, "Germans"),
                        (6, "Eve"), (6, "Eve"), (6, "Eve"), (7, "Gott"), (7, "Gott"), (7, "Gott")].map { mention($0.1, paragraph: $0.0) }
        #expect(CharacterRules.characters(from: mentions, sentences: sentences).map(\.name) == ["Brooke"])
    }

    @Test("CH-11 a pet form joins its name in any book; different surnames or a name mostly said with a title keep two people apart")
    func nicknamesInAnyBook() {
        let people = ["Lenny", "Len", "Josie Pye", "Josie", "Josephine Barry", "Josephine", "Kitty", "Lady Catherine"]
        let sentences = paragraphs(people.flatMap { name in ["laughed", "smiled", "nodded"].map { "\(name) \($0)." } })
        let mentions = people.indices.flatMap { person in (0..<3).map { mention(people[person], paragraph: person * 3 + $0) } }
        let names = CharacterRules.characters(from: mentions, sentences: sentences).map { Set($0.names) }
        #expect(names.contains { $0.isSuperset(of: ["Lenny", "Len"]) })
        #expect(names.contains { $0.contains("Josie") && !$0.contains("Josephine") })
        #expect(names.contains { $0 == ["Kitty"] })
    }

    @Test("CH-04 search finds any of a character's names, ignoring case, and forgives one typo in a longer search")
    func search() {
        let laurie = BookCharacter(name: "Laurie/Laurence", names: ["Laurie", "Laurence"], passage: nil)
        #expect(CharacterRules.matches(laurie, query: "laur"))
        #expect(CharacterRules.matches(laurie, query: "LAURENCE"))
        #expect(CharacterRules.matches(laurie, query: "Lauire"))
        #expect(CharacterRules.matches(laurie, query: ""))
        #expect(!CharacterRules.matches(laurie, query: "Haymitch"))
        #expect(!CharacterRules.matches(laurie, query: "Lx"))
    }
}
