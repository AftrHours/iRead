import Foundation

enum EvidenceKnobs {
    static let maxWordsBetweenGroupedNames = 4

    static let separatePeopleWords: Set<String> = ["and", "&", "with", "nor"]
}

enum EvidenceGuard {
    static func accepts(_ choice: LinkChoice, for request: LinkRequest) -> Bool {
        guard request.candidates.indices.contains(choice.candidateIndex),
              choice.evidenceSentence <= request.mention.sentence,
              request.sentences.contains(where: { $0.index == choice.evidenceSentence }) else { return false }
        return appears(request.candidates[choice.candidateIndex].label, in: request.sentences)
    }

    static func accepts(_ choice: NameGroupChoice, for request: NameGroupRequest) -> Bool {
        let asked = Set(request.names.map { $0.lowercased() })
        return choice.names.allSatisfy { asked.contains($0.lowercased()) } && supportedNames(choice, for: request).count >= 2
    }

    static func supportedNames(_ choice: NameGroupChoice, for request: NameGroupRequest) -> [String] {
        guard let evidence = request.sentences.first(where: { $0.index == choice.evidenceSentence }) else { return [] }
        let text = evidence.text as NSString
        var seen: Set<String> = []
        let found = choice.names
            .filter { seen.insert($0.lowercased()).inserted }
            .compactMap { name in wordRange(of: name, in: evidence.text).map { (name, $0) } }
            .sorted { $0.1.location < $1.1.location }
        guard found.count >= 2 else { return [] }
        for (left, right) in zip(found, found.dropFirst()) {
            let gapStart = left.1.location + left.1.length
            let gap = right.1.location > gapStart ? text.substring(with: NSRange(location: gapStart, length: right.1.location - gapStart)) : ""
            let words = gap.lowercased().split { !$0.isLetter && $0 != "&" }.map(String.init)
            if words.count > EvidenceKnobs.maxWordsBetweenGroupedNames || words.contains(where: EvidenceKnobs.separatePeopleWords.contains) {
                return []
            }
        }
        return found.map(\.0)
    }

    private static func appears(_ text: String, in sentences: [ModelSentence]) -> Bool {
        sentences.contains { wordRange(of: text, in: $0.text) != nil }
    }

    private static func wordRange(of word: String, in text: String) -> NSRange? {
        let pattern = #"(?<![\p{L}\p{N}])"# + NSRegularExpression.escapedPattern(for: word) + #"(?![\p{L}\p{N}])"#
        guard let range = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) else { return nil }
        return NSRange(range, in: text)
    }
}
