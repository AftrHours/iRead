import Foundation

enum SliceReadingApplier {
    static func apply(_ reading: SliceReading, request: SliceRequest, to chapter: inout LinkedChapter, vocabulary: NameVocabulary) {
        var analysis = ResolvedAnalysis(entities: chapter.memory.entities, mentions: chapter.mentions)
        let cards = Dictionary(uniqueKeysWithValues: request.cards.map { ($0.number, $0) })
        let listed = Dictionary(uniqueKeysWithValues: request.mentions.map { ($0.number, $0) })

        for assignment in reading.assignments where EvidenceGuard.accepts(assignment, for: request) {
            guard let target = listed[assignment.mention],
                  let index = analysis.mentions.firstIndex(where: { $0.sentence == target.sentence && $0.location == target.location }) else { continue }
            let mention = analysis.mentions[index]
            if mention.form == .name, mention.entity != nil { continue }
            analysis.mentions[index].entity = assignment.card.flatMap { cards[$0]?.entity }
            analysis.mentions[index].decidedBy = .model
            analysis.mentions[index].isUndecided = false
        }

        for span in reading.missedNames where EvidenceGuard.accepts(span, for: request) {
            guard let sentence = request.sentences.first(where: { $0.index == span.sentence }),
                  let location = EvidenceGuard.wordLocation(of: span.text, in: sentence.text) else { continue }
            let length = span.text.utf16.count
            guard !analysis.mentions.contains(where: { $0.sentence == span.sentence && $0.location < location + length && location < $0.location + $0.length }) else { continue }
            let key = NameKey.of(span.text)
            let entity = analysis.entityKey(forName: key) ?? newEntity(named: span.text, key: key, at: span.sentence, in: &analysis)
            analysis.mentions.append(ResolvedMention(sentence: span.sentence, location: location, length: length, text: span.text, form: .name,
                                                     head: key, modifiers: [], entity: entity, decidedBy: .model))
        }
        analysis.mentions.sort { ($0.sentence, $0.location) < ($1.sentence, $1.location) }

        for pair in reading.sameNames where EvidenceGuard.accepts(pair, for: request, memory: chapter.memory) {
            let first = NameKey.of(pair.first), second = NameKey.of(pair.second)
            switch (analysis.entityKey(forName: first), analysis.entityKey(forName: second)) {
            case let (a?, b?) where analysis.finalKey(of: a) != analysis.finalKey(of: b):
                let (earlier, later) = (analysis.entity(a)!.introSentence, a) <= (analysis.entity(b)!.introSentence, b) ? (a, b) : (b, a)
                analysis.merge(later, into: earlier, at: pair.evidence, decidedBy: .model)
            case let (a?, nil):
                addName(pair.second, key: second, to: a, at: pair.evidence, in: &analysis)
            case let (nil, b?):
                addName(pair.first, key: first, to: b, at: pair.evidence, in: &analysis)
            default:
                break
            }
        }

        chapter.mentions = analysis.mentions
        chapter.memory.entities = analysis.entities
        for trait in reading.traits where EvidenceGuard.accepts(trait, for: request) {
            guard let entity = cards[trait.card]?.entity,
                  analysis.mentions.contains(where: { $0.sentence == trait.sentence && analysis.entityKey(of: $0, asOf: trait.sentence) == entity }) else { continue }
            chapter.memory.traits[entity, default: []].append(CharacterTrait(text: trait.text, sentence: trait.sentence))
        }
    }

    private static func newEntity(named text: String, key: String, at sentence: Int, in analysis: inout ResolvedAnalysis) -> Int {
        let entity = (analysis.entities.map(\.key).max() ?? 0) + 1
        analysis.entities.append(ResolvedEntity(key: entity, names: [EntityName(text: text, key: key, sinceSentence: sentence)],
                                                label: text, introSentence: sentence, mergeEdges: []))
        return entity
    }

    private static func addName(_ text: String, key: String, to entity: Int, at sentence: Int, in analysis: inout ResolvedAnalysis) {
        guard let index = analysis.entities.firstIndex(where: { $0.key == entity }) else { return }
        analysis.entities[index].names.append(EntityName(text: text, key: key, sinceSentence: sentence))
    }
}
