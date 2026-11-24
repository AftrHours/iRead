import Foundation
import Testing
@testable import iRead

@Suite("DescriptionRules")
struct DescriptionRulesTests {
    /// One paragraph's sentences, in order.
    private func paragraph(_ texts: [String], number: Int = 0) -> [ContextPassage] {
        var location = 0
        return texts.enumerated().map { index, text in
            defer { location += text.utf16.count + 1 }
            return ContextPassage(sentence: index, paragraph: number, range: NSRange(location: location, length: text.utf16.count), text: text)
        }
    }

    private func best(_ aliases: Set<String>, in sentences: [ContextPassage], others: Set<String> = []) -> ContextPassage? {
        DescriptionRules.bestDescription(of: aliases, at: Array(sentences.indices), in: sentences, otherNames: others)
    }

    @Test("DS-01 the character's introduction beats lines that only name them, and carries on into the next sentence about them")
    func introduction() throws {
        let sentences = paragraph(["“Christmas won’t be Christmas without any presents,” grumbled Jo, lying on the rug."])
            + paragraph(["Fifteen-year-old Jo was very tall, thin, and brown, and reminded one of a colt.",
                         "She had a decided mouth, a comical nose, and sharp, gray eyes.",
                         "Elizabeth, or Beth, as everyone called her, was a rosy, smooth-haired, bright-eyed girl of thirteen."], number: 1)
        let jo = try #require(best(["Jo"], in: sentences, others: ["Beth", "Elizabeth"]))
        #expect(jo.text.hasPrefix("Fifteen-year-old Jo was very tall"))
        #expect(jo.text.hasSuffix("sharp, gray eyes."))
        #expect(jo.range == NSRange(location: 0, length: NSMaxRange(sentences[2].range)))
        #expect(best(["Beth", "Elizabeth"], in: sentences, others: ["Jo"])?.text.hasPrefix("Elizabeth, or Beth") == true)
    }

    @Test("DS-02 a description that names no one else carries on, as in “A regular snow maiden, with blue eyes…”")
    func carriesOn() {
        let sentences = paragraph(["Amy, though the youngest, was a most important person, in her own opinion at least.",
                                   "A regular snow maiden, with blue eyes, and yellow hair curling on her shoulders, pale and slender."])
        #expect(best(["Amy"], in: sentences)?.text.hasSuffix("pale and slender.") == true)
    }

    @Test("DS-03 other novels: a subject with looks or an age and “a … girl” is found")
    func otherNovels() {
        let sentences = paragraph(["Bingley was good-looking and gentlemanlike: he had a pleasant countenance, and easy, unaffected manners."])
            + paragraph(["Lydia was a stout, well-grown girl of fifteen, with a fine complexion and good-humoured countenance."], number: 1)
        #expect(best(["Bingley"], in: sentences) == sentences[0])
        #expect(best(["Lydia"], in: sentences) == sentences[1])
    }

    @Test("DS-04 no description: a plain mention, a name only in dialogue, or only someone else's (“Elizabeth’s friend”)")
    func notDescriptions() {
        #expect(best(["Marmee"], in: paragraph(["Marmee is coming down the street, and Laurie is tramping through the garden."])) == nil)
        #expect(best(["Jo"], in: paragraph(["“Jo is a tall, thin, brown girl with a quick temper,” said Meg."])) == nil)
        #expect(best(["Elizabeth"], in: paragraph([
            "The eldest of them, a sensible, intelligent young woman, about twenty-seven, was Elizabeth’s intimate friend."
        ])) == nil)
    }

    @Test("DS-05 a description that names no one goes to the nearest character named before it whose gender matches")
    func unnamedDescription() {
        let sentences = paragraph(["Laurie’s bashfulness soon wore off, and he laughed with Jo."])
            + paragraph(["She liked the ‘Laurence boy’ better than ever and took several good looks at him."], number: 1)
            + paragraph(["“Curly black hair, brown skin, big black eyes, handsome nose, fine teeth, small hands and feet, very polite, for a boy.”"],
                        number: 2)
        let people = [
            DescriptionRules.Person(key: "laurie", aliases: ["Laurie"], surnames: [], gender: .male),
            DescriptionRules.Person(key: "jo", aliases: ["Jo"], surnames: [], gender: .female),
            DescriptionRules.Person(key: "mr laurence", aliases: ["Mr. Laurence", "Laurence"], surnames: ["Laurence"], gender: .male)
        ]
        let found = DescriptionRules.unnamedDescriptions(in: sentences, people: people, allNames: ["Laurie", "Jo", "Mr. Laurence", "Laurence"])
        #expect(found["laurie"] == sentences[2])
        #expect(found["jo"] == nil)
        #expect(found["mr laurence"] == nil)
    }

    @Test("DS-06 gender comes from the first he or she after the name, before anyone else is named")
    func gender() {
        let sentences = paragraph(["Laurie laughed, and he bowed.", "Jo smiled at Laurie, and he blushed.", "Jo said she would go."])
        #expect(DescriptionRules.gender(of: ["Laurie"], at: [0, 1], in: sentences, otherNames: ["Jo"]) == .male)
        #expect(DescriptionRules.gender(of: ["Jo"], at: [1, 2], in: sentences, otherNames: ["Laurie"]) == nil)
    }

    @Test("DS-07 a man's description doesn't take another person's part of the sentence, nor a sentence mostly about “her”")
    func someoneElse() {
        let darcy = paragraph(["His brother-in-law, Mr. Hurst, merely looked the gentleman; but his friend Mr. Darcy soon drew the attention "
                               + "of the room by his fine, tall person, handsome features, noble mien."])
        #expect(best(["Mr. Hurst"], in: darcy, others: ["Mr. Darcy"]) == nil)
        #expect(best(["Mr. Darcy"], in: darcy, others: ["Mr. Hurst"]) == darcy[0])
        let aboutHer = paragraph(["Mr. Darcy had at first scarcely allowed her to be pretty; he looked at her only to criticise "
                                  + "the beautiful expression of her dark eyes and her face."])
        #expect(DescriptionRules.bestDescription(of: ["Mr. Darcy"], at: [0], in: aboutHer, otherNames: [], gender: .male) == nil)
    }

    @Test("DS-08 a title says the gender before any pronoun does")
    func genderFromTitle() {
        let sentences = paragraph(["Lydia gaped as he opened the book.", "Lydia laughed, and he frowned."])
        #expect(DescriptionRules.gender(of: ["Lydia", "Miss Lydia"], at: [0, 1], in: sentences, otherNames: []) == .female)
        #expect(DescriptionRules.gender(of: ["Mr. Darcy"], at: [], in: sentences, otherNames: []) == .male)
    }
}
