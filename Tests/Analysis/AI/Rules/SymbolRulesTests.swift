import Foundation
import Testing
@testable import iRead

@Suite("Symbol rules: AppearancePicker, SymbolAssigner, AnalysisMapper")
struct SymbolRulesTests {
    private let noNames = NameVocabulary(names: [], nameCounts: [:])

    @Test("CH-16 a symbol card only shows an appearance the reader has reached")
    func noSpoilers() {
        let early = ContextPassage(paragraph: 5, range: NSRange(location: 0, length: 20), text: "She had red hair.")
        let later = ContextPassage(paragraph: 50, range: NSRange(location: 0, length: 40), text: "She was tall, with long red hair, blue eyes and a pale face.")
        #expect(AppearancePicker.best(in: [early, later], before: ReadingPosition(paragraph: 20, charOffset: 0))?.paragraph == 5)
    }

    @Test("CH-17 a sentence that describes two named characters isn't anyone's appearance")
    func twoCharacters() {
        let content = BookContent.make(chapters: [[
            "Anne had long red hair and blue eyes, and Diana had dark curls.",
            "Anne had long red hair and bright blue eyes."
        ]])
        let diana = (content.text(ofSentence: 0) as NSString).range(of: "Diana").location
        let links: [(mention: ResolvedMention, key: Int)] = [
            (.name("Anne", sentence: 0), 1), (.name("Diana", sentence: 0, at: diana), 2), (.name("Anne", sentence: 1), 1)
        ]
        let passages = AppearancePicker.passages(of: 1, in: links, named: [1, 2], content: content)
        #expect(passages.map(\.paragraph) == [1])
    }

    @Test("CH-20 a character needs 2 mentions to get a symbol")
    func twoMentions() {
        var memory = CastMemory(entities: [.unnamed("the boy", key: 1), .unnamed("the girl", key: 2)], traits: [:], symbols: [:])
        let mentions: [ResolvedMention] = [.description("the boy", head: "boy", sentence: 0, entity: 1)]
            + (1...3).map { .description("the girl", head: "girl", sentence: $0, entity: 2) }
        SymbolAssigner.assign(&memory, mentionsSoFar: mentions, vocabulary: noNames, chapter: 0)
        #expect(memory.symbols[1] == nil)
        #expect(memory.symbols[2] != nil)
    }

    @Test("CH-21 symbols already given stay; a new character gets the next one, wrapping after 24")
    func nextSymbol() {
        let symbols = AnalysisMapperKnobs.symbols
        var memory = CastMemory(entities: [.named("Anna", key: 1)], traits: [:], symbols: [:])
        SymbolAssigner.assign(&memory, mentionsSoFar: [], vocabulary: NameVocabulary(names: [], nameCounts: ["anna": 3]), chapter: 0)
        #expect(memory.symbols[1]?.symbolName == symbols[0])

        memory.entities.append(.named("Bella", key: 2, since: 10))
        SymbolAssigner.assign(&memory, mentionsSoFar: [], vocabulary: NameVocabulary(names: [], nameCounts: ["anna": 3, "bella": 3]), chapter: 1)
        #expect(memory.symbols[1]?.symbolName == symbols[0])
        #expect(memory.symbols[2]?.symbolName == symbols[1])

        let names = (1...25).map { "Name\($0)" }
        var many = CastMemory(entities: names.enumerated().map { .named($0.element, key: $0.offset + 1, since: $0.offset) }, traits: [:], symbols: [:])
        let counts = Dictionary(uniqueKeysWithValues: names.map { (NameKey.of($0), 2) })
        SymbolAssigner.assign(&many, mentionsSoFar: [], vocabulary: NameVocabulary(names: [], nameCounts: counts), chapter: 0)
        #expect(symbols.count == 24)
        #expect(many.symbols[24]?.symbolName == symbols[23])
        #expect(many.symbols[25]?.symbolName == symbols[0])
    }

    @Test("CH-22 a symbol given in chapter 3 hides that character's earlier mentions")
    func hiddenBeforeSymbol() throws {
        let content = BookContent.make(chapters: Array(repeating: ["Intro words here. The girl ran fast."], count: 3))
        // "The girl" starts each chapter's second sentence: sentences 1, 3 and 5.
        let memory = CastMemory(entities: [.unnamed("The girl", key: 7, since: 1)], traits: [:],
                                symbols: [7: SymbolAssignment(symbolName: "circle.fill", sinceChapter: 2)])
        let mentions = [1, 3, 5].map { ResolvedMention.description("The girl", head: "girl", sentence: $0, entity: 7) }

        let analysis = AnalysisMapper.map(memory: memory, mentions: mentions, content: content)
        #expect(analysis.entities.map(\.id) == ["character-7"])
        let mention = try #require(analysis.mentions.first)
        #expect(analysis.mentions.count == 1)
        #expect(mention.entityID == "character-7")
        #expect(mention.paragraph == 2)
        #expect(mention.range == NSRange(location: content.sentences[5].range.location, length: 8))
        #expect(mention.range.location == "Intro words here. ".utf16.count)
    }
}
