import Foundation

enum CastKnobs {
    static let minNameCount = 2

    static let aliasConnectors: [String] = [#"^,\s*or\s*$"#, #"^\s*or\s*$"#, #"^,\s*called\s*$"#, #"^,\s*known as\s*$"#]
}

extension EntityResolveSvc {
    static var castKnobSummary: String {
        "cast: min \(CastKnobs.minNameCount) names, \(CastKnobs.aliasConnectors.count) alias patterns"
    }

    func buildCast(from mentions: [ResolvedMention], sentences: [NumberedSentence], tags: SentenceTags) -> ResolvedAnalysis {
        var analysis = ResolvedAnalysis(tags: tags)
        let names = mentions.filter { $0.form == .name }
        let byKey = Dictionary(grouping: names, by: \.head)

        for mention in names where analysis.entityKey(forName: mention.head) == nil && (byKey[mention.head]?.count ?? 0) >= CastKnobs.minNameCount {
            let key = analysis.entities.count + 1
            analysis.entities.append(ResolvedEntity(key: key, kind: .character,
                                            names: [EntityName(text: mention.text, key: mention.head, sinceSentence: mention.sentence)],
                                            label: Self.mostFrequentText(of: byKey[mention.head] ?? []),
                                            introSentence: mention.sentence, mergeEdges: []))
        }

        let textByIndex = Dictionary(uniqueKeysWithValues: sentences.map { ($0.index, $0.text) })
        for (sentence, inSentence) in Dictionary(grouping: names, by: \.sentence).sorted(by: { $0.key < $1.key }) {
            let ordered = inSentence.sorted { $0.location < $1.location }
            guard ordered.count >= 2, let text = textByIndex[sentence] else { continue }
            for (first, second) in zip(ordered, ordered.dropFirst()) where isAlias(between: first, and: second, in: text) {
                joinNames(first, second, at: sentence, decidedBy: .rule, in: &analysis)
            }
        }
        return analysis
    }

    func joinNames(_ first: ResolvedMention, _ second: ResolvedMention, at sentence: Int, decidedBy: DecidedBy, in analysis: inout ResolvedAnalysis) {
        switch (analysis.entityKey(forName: first.head), analysis.entityKey(forName: second.head)) {
        case let (a?, b?):

            let (earlier, later) = (analysis.entity(a)?.introSentence ?? .max, a) <= (analysis.entity(b)?.introSentence ?? .max, b) ? (a, b) : (b, a)
            analysis.merge(later, into: earlier, at: sentence, decidedBy: decidedBy)
        case let (a?, nil):
            analysis.addName(second, to: a, at: sentence)
        case let (nil, b?):
            analysis.addName(first, to: b, at: sentence)
        case (nil, nil):
            break
        }
    }

    private func isAlias(between first: ResolvedMention, and second: ResolvedMention, in text: String) -> Bool {
        let gapStart = first.location + first.length
        guard second.location >= gapStart else { return false }
        let gap = (text as NSString).substring(with: NSRange(location: gapStart, length: second.location - gapStart)).lowercased()
        return CastKnobs.aliasConnectors.contains { gap.range(of: $0, options: .regularExpression) != nil }
    }

    private static func mostFrequentText(of mentions: [ResolvedMention]) -> String {
        Dictionary(grouping: mentions, by: \.text).max { $0.value.count < $1.value.count }?.key ?? mentions.first?.text ?? ""
    }
}

extension ResolvedAnalysis {
    func entityKey(forName key: String) -> Int? {
        entities.first { $0.names.contains { $0.key == key } }?.key
    }

    mutating func addName(_ mention: ResolvedMention, to key: Int, at sentence: Int) {
        guard let i = entities.firstIndex(where: { $0.key == key }) else { return }
        entities[i].names.append(EntityName(text: mention.text, key: mention.head, sinceSentence: sentence))
    }
}
