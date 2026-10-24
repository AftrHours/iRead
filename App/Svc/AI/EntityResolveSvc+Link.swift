import Foundation

enum LinkKnobs {
    static let sameHeadScore = 2.0
    static let synonymScore = 1.5
    static let sharedModifierScore = 2.0

    static let strongMatchTotal = 3.5
    static let strongMatchModifiers = 2.0

    static let minMentionsForDescribedEntity = 2

    static let appositionConnectors: [String] = [#"^,\s*$"#, #"^,\s*(who|that)\s+(was|is)\s*$"#]

    static let minLengthToStripEd = 5
}

extension EntityResolveSvc {
    static var linkKnobSummary: String {
        "link: strong ≥ \(LinkKnobs.strongMatchTotal)/\(LinkKnobs.strongMatchModifiers), min \(LinkKnobs.minMentionsForDescribedEntity) mentions"
    }

    func linkMentions(_ mentions: [ResolvedMention], sentences: [NumberedSentence], cast: ResolvedAnalysis) -> RulesResult {
        var result = RulesResult(analysis: cast, undecided: [])
        let textByIndex = Dictionary(uniqueKeysWithValues: sentences.map { ($0.index, $0.text) })

        for var mention in mentions.sorted(by: { ($0.sentence, $0.location) < ($1.sentence, $1.location) }) {
            switch mention.form {
            case .name:
                mention.entity = knownName(mention, in: result.analysis)
            case .description:
                if let named = appositionTarget(of: mention, in: result.analysis, text: textByIndex[mention.sentence] ?? "") {
                    if case .one(let described) = bestMatch(for: mention, in: result.analysis),
                       result.analysis.entity(described)?.isNamed == false {
                        result.analysis.merge(described, into: named, at: mention.sentence, decidedBy: .rule)
                    }
                    mention.entity = named
                } else if case .one(let key) = bestMatch(for: mention, in: result.analysis) {
                    mention.entity = key
                } else {
                    mention.entity = openDescribedEntity(for: mention, in: &result.analysis)
                    result.undecided.append(result.analysis.mentions.count)
                }
            }
            if mention.entity != nil { mention.decidedBy = .rule }
            result.analysis.mentions.append(mention)
        }
        return result
    }

    private func knownName(_ mention: ResolvedMention, in analysis: ResolvedAnalysis) -> Int? {
        analysis.entities.first { entity in
            entity.names.contains { $0.key == mention.head && $0.sinceSentence <= mention.sentence }
        }?.key
    }

    private func appositionTarget(of mention: ResolvedMention, in analysis: ResolvedAnalysis, text: String) -> Int? {
        guard let previous = analysis.mentions.last(where: {
            $0.sentence == mention.sentence && $0.form == .name && $0.entity != nil && $0.location < mention.location
        }), let key = previous.entity else { return nil }
        let gapStart = previous.location + previous.length
        guard mention.location >= gapStart else { return nil }
        let gap = (text as NSString).substring(with: NSRange(location: gapStart, length: mention.location - gapStart)).lowercased()
        return LinkKnobs.appositionConnectors.contains { gap.range(of: $0, options: .regularExpression) != nil } ? key : nil
    }

    enum Match { case none, one(Int), tie }

    func bestMatch(for mention: ResolvedMention, in analysis: ResolvedAnalysis) -> Match {
        var best: [Int: Double] = [:]
        for earlier in analysis.mentions where earlier.form == .description && earlier.sentence <= mention.sentence {
            guard let score = strongScore(mention, earlier), let key = analysis.entityKey(of: earlier, asOf: mention.sentence) else { continue }
            best[key] = max(best[key] ?? 0, score)
        }
        guard let top = best.values.max() else { return .none }
        let winners = best.filter { $0.value == top }.map(\.key)
        return winners.count == 1 ? .one(winners[0]) : .tie
    }

    private func strongScore(_ a: ResolvedMention, _ b: ResolvedMention) -> Double? {
        let headScore: Double
        if a.head == b.head {
            headScore = LinkKnobs.sameHeadScore
        } else if let group = MentionKnobs.personHeads[a.head], group == MentionKnobs.personHeads[b.head] {
            headScore = LinkKnobs.synonymScore
        } else {
            return nil
        }
        let shared = Set(Self.comparable(a.modifiers)).intersection(Self.comparable(b.modifiers))
        let modifierScore = Double(shared.count) * LinkKnobs.sharedModifierScore
        let total = headScore + modifierScore
        return total >= LinkKnobs.strongMatchTotal && modifierScore >= LinkKnobs.strongMatchModifiers ? total : nil
    }

    private static func comparable(_ modifiers: [String]) -> [String] {
        modifiers.flatMap { $0.lowercased().split(separator: "-").map(String.init) }.map { word in
            word.count >= LinkKnobs.minLengthToStripEd && word.hasSuffix("ed") ? String(word.dropLast(2)) : word
        }
    }

    private func openDescribedEntity(for mention: ResolvedMention, in analysis: inout ResolvedAnalysis) -> Int {
        let key = (analysis.entities.map(\.key).max() ?? 0) + 1
        analysis.entities.append(ResolvedEntity(key: key, kind: .character, names: [], label: mention.text,
                                        introSentence: mention.sentence, mergeEdges: []))
        return key
    }

    func dropSmallDescribedEntities(in analysis: inout ResolvedAnalysis) {
        let counts = Dictionary(grouping: analysis.linkedMentions, by: { $0.entity! }).mapValues(\.count)
        let small = Set(analysis.entities.filter {
            !$0.isNamed && $0.mergeEdges.isEmpty && (counts[$0.key] ?? 0) < LinkKnobs.minMentionsForDescribedEntity
        }.map(\.key))
        guard !small.isEmpty else { return }
        for i in analysis.mentions.indices where analysis.mentions[i].entity.map(small.contains) == true {
            analysis.mentions[i].entity = nil
            analysis.mentions[i].decidedBy = nil
        }
        analysis.entities.removeAll { small.contains($0.key) }
        for i in analysis.entities.indices {
            analysis.entities[i].mergeEdges.removeAll { small.contains($0.into) }
        }
    }
}
