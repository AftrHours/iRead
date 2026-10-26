import Foundation

enum EvidenceKnobs {
    static let maxWordsBetweenGroupedNames = 4

    static let separatePeopleWords: Set<String> = ["and", "&", "with", "nor"]
}

enum EvidenceGuard {
    static func accepts(_ assignment: MentionAssignment, for request: SliceRequest) -> Bool {
        guard let mention = request.mentions.first(where: { $0.number == assignment.mention }),
              assignment.evidence <= mention.sentence,
              request.sentences.contains(where: { $0.index == assignment.evidence }) else { return false }
        return assignment.card.map { card in
            request.cards.contains { $0.number == card && $0.introSentence <= mention.sentence }
        } ?? true
    }

    static func accepts(_ span: NamedSpan, for request: SliceRequest) -> Bool {
        guard span.text.first?.isUppercase == true,
              let sentence = request.sentences.first(where: { $0.index == span.sentence }) else { return false }
        return wordLocation(of: span.text, in: sentence.text) != nil
    }

    static func accepts(_ pair: NamePair, for request: SliceRequest, memory: CastMemory) -> Bool {
        guard let evidence = request.sentences.first(where: { $0.index == pair.evidence }) else { return false }
        let known = Set(request.cards.flatMap { [$0.name] + $0.aliases }.map { $0.lowercased() })
        func present(_ name: String) -> Bool {
            known.contains(name.lowercased()) || request.sentences.contains { wordRange(of: name, in: $0.text) != nil }
        }
        let firstInEvidence = wordRange(of: pair.first, in: evidence.text) != nil
        let secondInEvidence = wordRange(of: pair.second, in: evidence.text) != nil
        return (firstInEvidence && present(pair.second)) || (secondInEvidence && present(pair.first))
    }

    static func accepts(_ trait: TraitNote, for request: SliceRequest) -> Bool {
        guard request.cards.contains(where: { $0.number == trait.card }), !trait.text.isEmpty,
              let sentence = request.sentences.first(where: { $0.index == trait.sentence }) else { return false }
        return sentence.text.range(of: trait.text, options: .caseInsensitive) != nil
    }

    static func wordLocation(of word: String, in text: String) -> Int? {
        guard let range = text.range(of: #"(?<![\p{L}\p{N}])"# + NSRegularExpression.escapedPattern(for: word) + #"(?![\p{L}\p{N}])"#,
                                     options: .regularExpression) else { return nil }
        return NSRange(range, in: text).location
    }

    private static func wordRange(of word: String, in text: String) -> NSRange? {
        let pattern = #"(?<![\p{L}\p{N}])"# + NSRegularExpression.escapedPattern(for: word) + #"(?![\p{L}\p{N}])"#
        guard let range = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) else { return nil }
        return NSRange(range, in: text)
    }
}
