import Foundation

enum CastCardsKnobs {
    static let maxCards = 8
    static let introWords = 40
    static let traitsPerCard = 3
    static let aliasesPerCard = 3
    static let minDescribedMentions = 2
}

enum CastCards {
    static func cards(for slice: [NumberedSentence], mentions: [ResolvedMention], memory: CastMemory,
                      sentenceText: [Int: String], maxCards: Int) -> [CastCard] {
        guard let start = slice.first?.index, let end = slice.last?.index else { return [] }
        let resolved = ResolvedAnalysis(entities: memory.entities, mentions: mentions)
        let before = mentions.filter { $0.sentence < start }
        let earlierCounts = Dictionary(grouping: before.compactMap { resolved.entityKey(of: $0, asOf: start) }, by: { $0 }).mapValues(\.count)
        func isCardWorthy(_ key: Int) -> Bool {
            guard let entity = resolved.entity(key), entity.introSentence <= end else { return false }
            return entity.isNamed || earlierCounts[key, default: 0] >= CastCardsKnobs.minDescribedMentions
        }
        let inSlice = mentions.filter { (start...end).contains($0.sentence) }.compactMap { resolved.entityKey(of: $0, asOf: start) }
        let named = inSlice.filter { resolved.entity($0)?.isNamed == true }
        let recent = before.reversed().compactMap { resolved.entityKey(of: $0, asOf: start) }
        var keys: [Int] = []
        for key in named + inSlice + recent where keys.count < maxCards && !keys.contains(key) && isCardWorthy(key) {
            keys.append(key)
        }
        return keys.enumerated().compactMap { index, key in
            guard let entity = resolved.entity(key) else { return nil }
            let names = entity.names.filter { $0.sinceSentence < start }.map(\.text)
            let name = names.first ?? entity.label
            return CastCard(
                number: index + 1,
                entity: key,
                name: name,
                aliases: Array(names.dropFirst().filter { $0 != name }.prefix(CastCardsKnobs.aliasesPerCard)),
                traits: (memory.traits[key] ?? []).filter { $0.sentence < start }.suffix(CastCardsKnobs.traitsPerCard).map(\.text),
                intro: (sentenceText[entity.introSentence] ?? "").split(separator: " ").prefix(CastCardsKnobs.introWords).joined(separator: " "),
                introSentence: entity.introSentence
            )
        }
    }
}
