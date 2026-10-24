import Foundation
import NaturalLanguage

enum TaggingKnobs {
    static let determiners: Set<String> = [
        "the", "a", "an", "this", "that", "these", "those", "his", "her", "its", "their", "my", "your", "our",
    ]
    static let pronouns: Set<String> = ["i", "you", "he", "she", "it", "we", "they", "me", "him", "them", "us"]
    static let prepositions: Set<String> = [
        "of", "in", "on", "at", "to", "from", "with", "by", "for", "about", "into", "over", "under", "through",
        "between", "after", "before", "near", "upon", "without",
    ]
    static let conjunctions: Set<String> = ["and", "but", "or", "so", "nor", "yet", "because", "if", "when", "while"]

    static let stitchHyphenatedWords = true
}

extension EntityResolveSvc {
    func detectTaggingEngine() -> TaggingEngine {
        let probe = "John walked to London."
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = probe
        tagger.setLanguage(.english, range: probe.startIndex..<probe.endIndex)
        let tag = tagger.tag(at: probe.startIndex, unit: .word, scheme: .nameType).0
        return tag == .personalName ? .naturalLanguage : .rules
    }

    func tagWords(in sentences: [String], engine: TaggingEngine) -> [[Token]] {
        switch engine {
        case .naturalLanguage:
            let tagger = NLTagger(tagSchemes: [.lexicalClass, .nameType, .lemma])
            return sentences.map { tokensByNaturalLanguage($0, tagger: tagger) }
        case .rules:
            return sentences.map(tokensByRules)
        case .skipped:
            return sentences.map { _ in [] }
        }
    }

    private func tokensByNaturalLanguage(_ sentence: String, tagger: NLTagger) -> [Token] {
        let range = sentence.startIndex..<sentence.endIndex
        tagger.string = sentence
        tagger.setLanguage(.english, range: range)
        var tokens: [Token] = []

        var lastStart = sentence.startIndex
        var lastEnd = sentence.startIndex
        tagger.enumerateTags(in: range, unit: .word, scheme: .lexicalClass,
                             options: [.omitWhitespace, .omitPunctuation, .omitOther]) { tag, wordRange in
            let word = String(sentence[wordRange])
            let nameTag = tagger.tag(at: wordRange.lowerBound, unit: .word, scheme: .nameType).0
            let lemma = (tagger.tag(at: wordRange.lowerBound, unit: .word, scheme: .lemma).0?.rawValue ?? word).lowercased()
            let name = [NLTag.personalName, .placeName, .organizationName].contains(nameTag) ? nameTag?.rawValue : nil
            let lexicalClass = tag?.rawValue ?? "Other"

            if TaggingKnobs.stitchHyphenatedWords, let last = tokens.last, sentence[lastEnd..<wordRange.lowerBound] == "-" {
                let stitched = lastStart..<wordRange.upperBound
                tokens[tokens.count - 1] = makeToken(String(sentence[stitched]), in: sentence, range: stitched,
                                                     lexicalClass: lexicalClass, name: name ?? last.name, lemma: last.lemma + "-" + lemma)
            } else {
                tokens.append(makeToken(word, in: sentence, range: wordRange, lexicalClass: lexicalClass, name: name, lemma: lemma))
                lastStart = wordRange.lowerBound
            }
            lastEnd = wordRange.upperBound
            return true
        }
        return tokens
    }

    private func tokensByRules(_ sentence: String) -> [Token] {
        let words = sentence.split { !$0.isLetter && $0 != "'" && $0 != "’" && $0 != "-" }
        return words.enumerated().map { position, piece in
            let word = String(piece)
            let lower = word.lowercased()
            let isCapitalised = word.first?.isUppercase == true && position > 0
            let lexicalClass: String
            if TaggingKnobs.determiners.contains(lower) { lexicalClass = "Determiner" }
            else if TaggingKnobs.pronouns.contains(lower) { lexicalClass = "Pronoun" }
            else if TaggingKnobs.prepositions.contains(lower) { lexicalClass = "Preposition" }
            else if TaggingKnobs.conjunctions.contains(lower) { lexicalClass = "Conjunction" }
            else if isCapitalised { lexicalClass = "Noun" }
            else { lexicalClass = "Word" }
            return makeToken(word, in: sentence, range: piece.startIndex..<piece.endIndex, lexicalClass: lexicalClass,
                             name: lexicalClass == "Noun" ? "Capitalised" : nil, lemma: lower)
        }
    }

    private func makeToken(_ text: String, in sentence: String, range: Range<String.Index>,
                           lexicalClass: String, name: String?, lemma: String) -> Token {
        let utf16 = NSRange(range, in: sentence)
        return Token(text: text, lexicalClass: lexicalClass, name: name, lemma: lemma, start: utf16.location, length: utf16.length)
    }
}
