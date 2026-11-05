import Foundation
import Testing
@testable import iRead

@Suite("Cast rules: CastBuilder, MentionLinker, merges")
struct CastRulesTests {
    @Test("CH-09 a name becomes a character only once it is seen twice")
    func seenTwice() {
        let mentions: [ResolvedMention] = [.name("Anna", sentence: 0), .name("Bella", sentence: 1)]
        let vocabulary = NameVocabulary(names: [], nameCounts: ["anna": 2, "bella": 1])
        let memory = CastBuilder.extend(.empty, with: mentions, sentences: [], vocabulary: vocabulary)
        #expect(memory.entities.map { $0.names.map(\.key) } == [["anna"]])
    }

    @Test("CH-10 \"Elizabeth, or Lizzy\" is one character with both names")
    func alias() {
        let text = "Elizabeth, or Lizzy, laughed."
        let mentions: [ResolvedMention] = [.name("Elizabeth", at: 0), .name("Lizzy", at: (text as NSString).range(of: "Lizzy").location)]
        let vocabulary = NameVocabulary(names: [], nameCounts: ["elizabeth": 2, "lizzy": 1])
        let memory = CastBuilder.extend(.empty, with: mentions, sentences: [NumberedSentence(index: 0, text: text)], vocabulary: vocabulary)
        #expect(memory.entities.count == 1)
        #expect(memory.entities.first?.names.map(\.key) == ["elizabeth", "lizzy"])
    }

    @Test("CH-11 a description right after a name links to that character")
    func apposition() {
        let text = "Anne, the red-haired girl, ran."
        let memory = CastMemory(entities: [.named("Anne", key: 1)], traits: [:], symbols: [:])
        let description = ResolvedMention.description("the red-haired girl", head: "girl", modifiers: ["red-haired"],
                                                      at: (text as NSString).range(of: "the red-haired girl").location)
        let linked = MentionLinker.link([.name("Anne"), description], memory: memory, earlier: [], sentences: [NumberedSentence(index: 0, text: text)])
        #expect(linked.mentions.map(\.entity) == [1, 1])
    }

    @Test("CH-12 a merge applies from its sentence on, and chains are followed")
    func merges() {
        var analysis = ResolvedAnalysis(entities: [.named("Anna", key: 1), .unnamed("the girl", key: 2), .unnamed("the child", key: 3)])
        analysis.merge(2, into: 1, at: 10, decidedBy: .rule)
        analysis.merge(3, into: 2, at: 12, decidedBy: .rule)
        let mention = ResolvedMention.description("the girl", head: "girl", entity: 2)
        #expect(analysis.entityKey(of: mention, asOf: 5) == 2)
        #expect(analysis.entityKey(of: mention, asOf: 10) == 1)
        #expect(analysis.finalKey(of: 2) == 1)
        #expect(analysis.finalKey(of: 3) == 1)
        #expect(analysis.entityKey(of: .description("the child", head: "child", entity: 3), asOf: 11) == 3)
    }

    @Test("CH-13 merge loops end, and merging into itself does nothing")
    func mergeLoops() {
        var analysis = ResolvedAnalysis(entities: [.named("Anna", key: 1), .named("Bella", key: 2)])
        analysis.merge(1, into: 2, at: 5, decidedBy: .rule)
        analysis.merge(2, into: 1, at: 6, decidedBy: .model)
        #expect(analysis.finalKey(of: 1) == 2)
        #expect(analysis.finalKey(of: 2) == 2)

        analysis.merge(1, into: 1, at: 7, decidedBy: .rule)
        #expect(analysis.entity(1)?.mergeEdges.count == 1)

        // A loop already on disk (1 → 2 → 1) still ends.
        var looped = ResolvedAnalysis(entities: [.named("Anna", key: 1), .named("Bella", key: 2)])
        looped.entities[0].mergeEdges = [MergeEdge(into: 2, mergedAtSentence: 1, decidedBy: .rule)]
        looped.entities[1].mergeEdges = [MergeEdge(into: 1, mergedAtSentence: 1, decidedBy: .rule)]
        #expect([1, 2].contains(looped.finalKey(of: 1)))
    }
}
