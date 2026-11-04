import Foundation
import Testing
@testable import iRead

@Suite("Evidence rules: EvidenceGuard, SliceReadingApplier")
struct EvidenceRulesTests {
    private func card(_ number: Int, entity: Int, name: String, introSentence: Int) -> CastCard {
        CastCard(number: number, entity: entity, name: name, aliases: [], traits: [], intro: "", introSentence: introSentence)
    }

    @Test("CH-14 evidence from after the mention, or a card introduced after it, is rejected (no spoilers)")
    func noLaterEvidence() {
        let request = SliceRequest(
            sentences: (5...7).map { ModelSentence(index: $0, text: "Sentence \($0).") },
            mentions: [SliceMention(number: 1, text: "the girl", sentence: 5, location: 0)],
            cards: [card(1, entity: 1, name: "Anna", introSentence: 3), card(2, entity: 2, name: "Bella", introSentence: 6)]
        )
        #expect(EvidenceGuard.accepts(MentionAssignment(mention: 1, card: 1, evidence: 5), for: request))
        #expect(!EvidenceGuard.accepts(MentionAssignment(mention: 1, card: 1, evidence: 6), for: request))
        #expect(!EvidenceGuard.accepts(MentionAssignment(mention: 1, card: 2, evidence: 5), for: request))
    }

    @Test("CH-15 a name matches whole words only")
    func wordLocation() {
        #expect(EvidenceGuard.wordLocation(of: "Ann", in: "Anne smiled") == nil)
        #expect(EvidenceGuard.wordLocation(of: "Ann", in: "Ann smiled") == 0)
    }

    @Test("CH-18 the model can't move a name that is already linked")
    func linkedNameKept() {
        var chapter = LinkedChapter(mentions: [.name("Anne", entity: 1)],
                                    memory: CastMemory(entities: [.named("Anne", key: 1), .named("Diana", key: 2)], traits: [:], symbols: [:]))
        let request = SliceRequest(sentences: [ModelSentence(index: 0, text: "Anne smiled.")],
                                   mentions: [SliceMention(number: 1, text: "Anne", sentence: 0, location: 0)],
                                   cards: [card(1, entity: 1, name: "Anne", introSentence: 0), card(2, entity: 2, name: "Diana", introSentence: 0)])
        let reading = SliceReading(assignments: [MentionAssignment(mention: 1, card: 2, evidence: 0)], missedNames: [], sameNames: [], traits: [])
        SliceReadingApplier.apply(reading, request: request, to: &chapter, vocabulary: NameVocabulary(names: [], nameCounts: [:]))
        #expect(chapter.mentions.map(\.entity) == [1])
    }

    @Test("CH-19 a missed name that overlaps a known mention isn't added")
    func overlappingMissedName() {
        let text = "Anne Shirley smiled at Diana."
        var chapter = LinkedChapter(mentions: [.name("Anne Shirley", entity: 1)],
                                    memory: CastMemory(entities: [.named("Anne Shirley", key: 1)], traits: [:], symbols: [:]))
        let request = SliceRequest(sentences: [ModelSentence(index: 0, text: text)], mentions: [], cards: [])
        let reading = SliceReading(assignments: [], missedNames: [NamedSpan(text: "Shirley", sentence: 0), NamedSpan(text: "Diana", sentence: 0)],
                                   sameNames: [], traits: [])
        SliceReadingApplier.apply(reading, request: request, to: &chapter, vocabulary: NameVocabulary(names: [], nameCounts: [:]))
        #expect(chapter.mentions.map(\.text) == ["Anne Shirley", "Diana"])
    }
}
