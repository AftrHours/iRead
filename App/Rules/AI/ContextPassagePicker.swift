import Foundation

enum ContextPassageKnobs {
    static let underlinedForms: Set<MentionForm> = [.description]
}

enum ContextPassagePicker {
    static func sentence(for mention: ResolvedMention, among sameEntity: [ResolvedMention], in resolved: ResolvedAnalysis) -> Int? {
        guard ContextPassageKnobs.underlinedForms.contains(mention.form),
              let key = resolved.entityKey(of: mention, asOf: mention.sentence) else { return nil }
        let earlier = sameEntity.filter {
            $0.sentence < mention.sentence && resolved.entityKey(of: $0, asOf: mention.sentence) == key
        }
        let sameDescription = earlier.filter { $0.form == .description && $0.head == mention.head }
        let best = sameDescription.max { overlap($0, mention) < overlap($1, mention) || (overlap($0, mention) == overlap($1, mention) && $0.sentence > $1.sentence) }
        return (best ?? earlier.min { $0.sentence < $1.sentence })?.sentence
    }

    private static func overlap(_ candidate: ResolvedMention, _ mention: ResolvedMention) -> Int {
        Set(candidate.modifiers).intersection(mention.modifiers).count
    }
}
