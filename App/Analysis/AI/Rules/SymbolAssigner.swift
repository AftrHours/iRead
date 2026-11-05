import Foundation

enum SymbolAssigner {
    static func assign(_ memory: inout CastMemory, mentionsSoFar: [ResolvedMention], vocabulary: NameVocabulary, chapter: Int) {
        let resolved = ResolvedAnalysis(entities: memory.entities, mentions: mentionsSoFar)
        let links = resolved.linkedMentions.compactMap { mention in
            resolved.entityKey(of: mention, asOf: mention.sentence).map { (mention: mention, key: $0) }
        }
        let counts = Dictionary(grouping: links, by: \.key).mapValues(\.count)
        let qualified = memory.entities
            .filter { memory.symbols[$0.key] == nil && resolved.finalKey(of: $0.key) == $0.key }
            .filter { !AnalysisMapperKnobs.onlyNamed || $0.isNamed }
            .filter { entity in
                let count = entity.isNamed
                    ? entity.names.map { vocabulary.nameCounts[$0.key, default: 0] }.max() ?? 0
                    : counts[entity.key, default: 0]
                return count >= AnalysisMapperKnobs.minimumMentions
            }
            .sorted { order(of: $0, in: links) < order(of: $1, in: links) }
        for entity in qualified {
            let symbols = AnalysisMapperKnobs.symbols
            memory.symbols[entity.key] = SymbolAssignment(
                symbolName: symbols[memory.symbols.count % symbols.count],
                sinceChapter: entity.isNamed ? 0 : chapter
            )
        }
    }

    private static func order(of entity: ResolvedEntity, in links: [(mention: ResolvedMention, key: Int)]) -> (Int, Int, Int) {
        let first = links.filter { $0.key == entity.key && $0.mention.sentence == entity.introSentence }.map { $0.mention.location }.min()
        return (entity.introSentence, first ?? Int.max, entity.key)
    }
}
