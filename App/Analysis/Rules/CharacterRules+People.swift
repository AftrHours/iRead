import Foundation

/// Whether a name found in the book is a person: not an ordinary word, a place, a group or a title.
extension CharacterRules {
    /// Not a word ("Good", "Him", "You’ve"), a title alone ("Lady"), a place ("Washington", "Italy"), a group ("Germans",
    /// "the Brookes", "Frenchman") or someone only talked about in dialogue ("Napoleon"). A name with a title is a person.
    static func isPerson(_ names: Set<String>, wordCase: [String: (lower: Int, capital: Int)], sentences: [ContextPassage],
                         narration: [String], sentencesByWord: [String: [Int]], knownWords: Set<String>) -> Bool {
        let parts = names.map(words(of:))
        guard parts.allSatisfy({ ($0.last?.count ?? 0) > 1 }), !parts.allSatisfy({ $0.count == 1 && isTitle($0[0]) }),
              !parts.allSatisfy({ $0.count == 1 && isGroup($0[0], wordCase: wordCase) }) else { return false }
        let pattern = names.sorted { $0.count > $1.count }.map(NSRegularExpression.escapedPattern(for:)).joined(separator: "|")
        let candidates = Set(parts.flatMap { sentencesByWord[$0[0]] ?? [] }).sorted()
        let uses = Uses(pattern: pattern, sentences: candidates.map { (sentences[$0].text, narration[$0]) }, knownWords: knownWords)
        // No text to judge by, as in a test with names only.
        if sentences.isEmpty { return true }
        guard uses.inNarration > 0 else { return false }
        if parts.contains(where: { $0.count > 1 && isTitle($0[0]) }) { return true }
        // Written in lowercase at least as often as capitalised: an ordinary word that starts a sentence.
        if parts.allSatisfy({ part in wordCase[part[0].lowercased()].map { $0.lower >= $0.capital } ?? false }) { return false }
        // "Christmas Eve", "Pilgrim’s Progress", "New York": part of a longer name.
        if uses.withArticle * 2 >= uses.all || uses.inLongerName * 2 >= uses.all { return false }
        return uses.asPlace < 2 || uses.asPlace < 2 * uses.asPerson
    }

    /// A plural of another capitalised word ("Germans", "Brookes") or one of a people ("Frenchman", "Englishwoman").
    private static func isGroup(_ word: String, wordCase: [String: (lower: Int, capital: Int)]) -> Bool {
        let lower = word.lowercased()
        let stems = [lower.hasSuffix("s") ? String(lower.dropLast()) : nil]
            + ["man", "woman", "men", "women"].map { lower.hasSuffix($0) ? String(lower.dropLast($0.count)) : nil }
        return stems.compactMap { $0 }.contains { $0.count > 1 && wordCase[$0]?.capital ?? 0 > 0 }
    }

    /// How often each word is written in lowercase and capitalised. Headings in capitals ("CHAPTER SEVEN") don't count.
    static func wordCaseCounts(in sentences: [ContextPassage]) -> [String: (lower: Int, capital: Int)] {
        var counts: [String: (lower: Int, capital: Int)] = [:]
        for sentence in sentences {
            for word in sentence.text.split(whereSeparator: { !$0.isLetter && $0 != "’" && $0 != "'" }) {
                guard let first = word.first, word.contains(where: \.isLowercase) else { continue }
                let key = word.lowercased()
                if first.isUppercase { counts[key, default: (0, 0)].capital += 1 } else { counts[key, default: (0, 0)].lower += 1 }
            }
        }
        return counts
    }

    /// The ways a name is used across the sentences it's in.
    private struct Uses {
        var all = 0, inNarration = 0, withArticle = 0, inLongerName = 0, asPlace = 0, asPerson = 0

        /// Each sentence's text, and the same without what's said in it.
        /// `knownWords`: names and titles, which can stand next to a name ("Jo March", "Mr. Brooke").
        init(pattern: String, sentences: [(text: String, narration: String)], knownWords: Set<String>) {
            let knobs = CharacterRulesKnobs.self
            let name = "(?:\(pattern))\\b(?![’']s)"
            guard let any = try? NSRegularExpression(pattern: "\\b\(name)"),
                  let article = try? NSRegularExpression(pattern: "\\b(?i:the|a|an)\\s+\(name)"),
                  // "in Washington", "in New York", "a Washington hospital"
                  let place = try? NSRegularExpression(pattern: "\\b(?i:\(knobs.placeWords))(?:\\s+all|\\s+[A-Z][a-z]+)?\\s+\(name)"
                                                       + "|\\b(?i:\(knobs.determiners))\\s+\(name)\\s+[a-z]"),
                  let person = try? NSRegularExpression(pattern: "\\b(?:\(knobs.personVerbs))\\s+(?:\(pattern))\\b"
                                                        + "|\\b(?:\(pattern))[,”\\s]+(?:\(knobs.personVerbs))\\b")
            else { return }
            // Places are counted in the narration: in dialogue, people are "my Beth" too.
            for (text, narration) in sentences {
                let matches = any.matches(in: text, range: NSRange(location: 0, length: (text as NSString).length))
                all += matches.count
                inLongerName += matches.filter { Self.isInLongerName($0.range, in: text as NSString, knownWords: knownWords) }.count
                let narrationRange = NSRange(location: 0, length: (narration as NSString).length)
                inNarration += any.numberOfMatches(in: narration, range: narrationRange)
                withArticle += article.numberOfMatches(in: text, range: NSRange(location: 0, length: (text as NSString).length))
                asPlace += place.numberOfMatches(in: narration, range: narrationRange)
                asPerson += person.numberOfMatches(in: text, range: NSRange(location: 0, length: (text as NSString).length))
            }
        }

        /// Next to another capitalised word that isn't a name, a title or a sentence's first word.
        private static func isInLongerName(_ range: NSRange, in text: NSString, knownWords: Set<String>) -> Bool {
            let before = text.substring(to: range.location), after = text.substring(from: NSMaxRange(range))
            if let word = before.range(of: "[A-Z][a-z]+(?=(?:[’']s)?\\s+$)", options: .regularExpression).map({ String(before[$0]) }),
               !knownWords.contains(word),
               before.range(of: "(?:^|[.!?“”\"]\\s*)\(word)(?:[’']s)?\\s+$", options: .regularExpression) == nil {
                return true
            }
            if let word = after.range(of: "^\\s+[A-Z][a-z]+", options: .regularExpression)
                .map({ String(after[$0]).trimmingCharacters(in: .whitespaces) }) {
                return !knownWords.contains(word)
            }
            return false
        }
    }
}
