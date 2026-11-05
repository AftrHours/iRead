import Foundation

enum AnalysisMapperKnobs {
    static let minimumMentions = 2
    static let onlyNamed = false
    static let symbols = [
        "circle.fill", "square.fill", "triangle.fill", "diamond.fill", "hexagon.fill", "star.fill",
        "heart.fill", "pentagon.fill", "octagon.fill", "moon.fill", "drop.fill", "bolt.fill",
        "capsule.fill", "rhombus.fill", "seal.fill", "shield.fill", "flame.fill", "leaf.fill",
        "cloud.fill", "crown.fill", "bell.fill", "key.fill", "flag.fill", "sun.max.fill"
    ]
}

enum AnalysisMapper {
    static func map(memory: CastMemory, mentions allMentions: [ResolvedMention], content: BookContent) -> BookAnalysis {
        let resolved = ResolvedAnalysis(entities: memory.entities, mentions: allMentions)
        let links = resolved.linkedMentions.compactMap { mention in
            resolved.entityKey(of: mention, asOf: mention.sentence).map { (mention: mention, key: $0) }
        }
        let kept = memory.entities
            .filter { memory.symbols[$0.key] != nil }
            .sorted { order(of: $0, in: links) < order(of: $1, in: links) }
        let namedKeys = Set(memory.entities.filter(\.isNamed).map(\.key))
        let entities = kept.map { entity in
            Entity(
                id: id(of: entity.key),
                name: entity.label,
                symbolName: memory.symbols[entity.key]?.symbolName ?? "",
                appearances: AppearancePicker.passages(of: entity.key, in: links, named: namedKeys, content: content),
                names: entity.names.map(\.text)
            )
        }
        let shown = links.filter { link in
            guard let symbol = memory.symbols[link.key] else { return false }
            return chapter(of: link.mention.sentence, in: content) >= symbol.sinceChapter
        }
        let mentions = shown.map { link in
            let sentence = content.sentences[link.mention.sentence]
            return Mention(
                entityID: id(of: link.key),
                paragraph: sentence.paragraph,
                range: NSRange(location: sentence.range.location + link.mention.location, length: link.mention.length)
            )
        }
        return BookAnalysis(entities: entities, mentions: mentions)
    }

    private static func chapter(of sentence: Int, in content: BookContent) -> Int {
        content.paragraphs[content.sentences[sentence].paragraph].chapterIndex
    }

    private static func order(of entity: ResolvedEntity, in links: [(mention: ResolvedMention, key: Int)]) -> (Int, Int, Int) {
        let first = links.filter { $0.key == entity.key && $0.mention.sentence == entity.introSentence }.map { $0.mention.location }.min()
        return (entity.introSentence, first ?? Int.max, entity.key)
    }

    private static func id(of key: Int) -> String {
        "character-\(key)"
    }
}
