import Foundation

enum AnalysisMapperKnobs {
    static let minimumMentions = 20
    static let onlyNamed = false
    static let symbols = [
        "circle.fill", "square.fill", "triangle.fill", "diamond.fill", "hexagon.fill", "star.fill",
        "heart.fill", "pentagon.fill", "octagon.fill", "moon.fill", "drop.fill", "bolt.fill",
        "capsule.fill", "rhombus.fill", "seal.fill", "shield.fill", "flame.fill", "leaf.fill",
        "cloud.fill", "crown.fill", "bell.fill", "key.fill", "flag.fill", "sun.max.fill"
    ]
}

enum AnalysisMapper {
    static func map(_ resolved: ResolvedAnalysis, content: BookContent) -> BookAnalysis {
        let links = resolved.linkedMentions.compactMap { mention in
            resolved.entityKey(of: mention, asOf: mention.sentence).map { (mention: mention, key: $0) }
        }
        let mentionCounts = Dictionary(grouping: links, by: \.key).mapValues(\.count)
        let kept = mentionCounts.keys
            .compactMap { resolved.entity($0) }
            .filter { mentionCounts[$0.key, default: 0] >= AnalysisMapperKnobs.minimumMentions }
            .filter { !AnalysisMapperKnobs.onlyNamed || $0.isNamed }
            .sorted { $0.introSentence < $1.introSentence }
        let entities = kept.enumerated().map { index, entity in
            Entity(
                id: id(of: entity.key),
                name: entity.label,
                symbolName: AnalysisMapperKnobs.symbols[index % AnalysisMapperKnobs.symbols.count],
                summary: SentenceText.of(content.sentences[entity.introSentence], in: content),
                names: entity.names.map(\.text)
            )
        }
        let keptKeys = Set(kept.map(\.key))
        let sameEntity = Dictionary(grouping: links) { resolved.finalKey(of: $0.key) }
        let mentions = links.filter { keptKeys.contains($0.key) }.map { link in
            let sentence = content.sentences[link.mention.sentence]
            let passageSentence = ContextPassagePicker.sentence(
                for: link.mention,
                among: sameEntity[resolved.finalKey(of: link.key), default: []].map(\.mention),
                in: resolved
            )
            return Mention(
                entityID: id(of: link.key),
                paragraph: sentence.paragraph,
                range: NSRange(location: sentence.range.location + link.mention.location, length: link.mention.length),
                passage: passageSentence.map { passage(at: $0, in: content) }
            )
        }
        return BookAnalysis(entities: entities, mentions: mentions)
    }

    private static func passage(at index: Int, in content: BookContent) -> ContextPassage {
        let sentence = content.sentences[index]
        return ContextPassage(paragraph: sentence.paragraph, range: sentence.range, text: SentenceText.of(sentence, in: content))
    }

    static func id(of key: Int) -> String {
        "character-\(key)"
    }
}
