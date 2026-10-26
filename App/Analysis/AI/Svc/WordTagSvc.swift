import Foundation
import NaturalLanguage

enum WordTagKnobs {
    static let determiners: Set<String> = [
        "the", "a", "an", "this", "that", "these", "those", "his", "her", "its", "their", "my", "your", "our"
    ]
    static let pronouns: Set<String> = ["i", "you", "he", "she", "it", "we", "they", "me", "him", "them", "us"]
    static let prepositions: Set<String> = [
        "of", "in", "on", "at", "to", "from", "with", "by", "for", "about", "into", "over", "under", "through",
        "between", "after", "before", "near", "upon", "without"
    ]
    static let conjunctions: Set<String> = ["and", "but", "or", "so", "nor", "yet", "because", "if", "when", "while"]

    static let stitchHyphenatedWords = true
}

struct WordTagSvc: Sendable {
    func tag(_ sentences: [NumberedSentence]) -> SentenceTags {
        let texts = sentences.map(\.text)
        guard hasEnglishModels() else { return SentenceTags(tokens: texts.map(tokensByRules)) }
        let tagger = NLTagger(tagSchemes: [.lexicalClass, .nameType, .lemma])
        return SentenceTags(tokens: texts.map { tokensByNaturalLanguage($0, tagger: tagger) })
    }

    func hasEnglishModels() -> Bool {
        let probe = "John walked to London."
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = probe
        tagger.setLanguage(.english, range: probe.startIndex..<probe.endIndex)
        return tagger.tag(at: probe.startIndex, unit: .word, scheme: .nameType).0 == .personalName
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

            if WordTagKnobs.stitchHyphenatedWords, let last = tokens.last, sentence[lastEnd..<wordRange.lowerBound] == "-" {
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
            let lexicalClass = if WordTagKnobs.determiners.contains(lower) {
                "Determiner"
            } else if WordTagKnobs.pronouns.contains(lower) {
                "Pronoun"
            } else if WordTagKnobs.prepositions.contains(lower) {
                "Preposition"
            } else if WordTagKnobs.conjunctions.contains(lower) {
                "Conjunction"
            } else if isCapitalised {
                "Noun"
            } else {
                "Word"
            }
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
