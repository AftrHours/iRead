import Foundation

enum NameVocabularyBuilder {
    static func build(sentences: [NumberedSentence], tags: SentenceTags) -> NameVocabulary {
        let names = knownNames(in: tags)
        let found = MentionFinder.mentions(in: sentences, tags: tags, names: names).filter { $0.form == .name }
        return NameVocabulary(names: names, nameCounts: Dictionary(grouping: found, by: \.head).mapValues(\.count))
    }

    private static func knownNames(in tags: SentenceTags) -> Set<String> {
        guard MentionFinderKnobs.propagateKnownNames else { return [] }
        var tagged: Set<String> = []
        var capitalizedMidSentence: [String: Int] = [:]
        var lowercase: [String: Int] = [:]
        for tokens in tags.tokens {
            for (position, token) in tokens.enumerated() {
                let word = token.text.lowercased()
                if token.text.first?.isUppercase != true {
                    lowercase[word, default: 0] += 1
                    continue
                }
                if token.name.map(MentionFinderKnobs.personNameTypes.contains) == true { tagged.insert(word) }
                if position > 0 { capitalizedMidSentence[word, default: 0] += 1 }
            }
        }
        return tagged.filter { word in
            let capitalized = capitalizedMidSentence[word, default: 0]
            return capitalized >= MentionFinderKnobs.minCapitalizedMidSentence
                && Double(lowercase[word, default: 0]) <= Double(capitalized) * MentionFinderKnobs.maxLowercaseRatio
        }
    }
}
