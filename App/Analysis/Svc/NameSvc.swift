import Foundation
import NaturalLanguage

/// People's names, with the same tagger the engine uses inside. On the Simulator (no English models), capitalised words instead.
struct NameSvc: Sendable {
    private let hasEnglishModels = Self.englishModelsInstalled()

    func names(inChapter index: Int, of content: BookContent) -> [NameMention] {
        let chapter = content.chapters[index]
        let text = chapter.text
        let found = hasEnglishModels ? taggedNames(in: text) : capitalisedWords(in: text)
        return found.map { name, offset in
            NameMention(name: withTitle(name, at: offset, in: text as NSString),
                        position: position(ofChapterOffset: offset, in: chapter, of: content))
        }
    }

    private func withTitle(_ name: String, at offset: Int, in text: NSString) -> String {
        if let first = name.split(separator: " ").first, CharacterRulesKnobs.titles.contains(first.lowercased().trimmingCharacters(in: ["."])) {
            return name
        }
        let start = max(0, offset - 12)
        let before = text.substring(with: NSRange(location: start, length: offset - start))
        guard let title = before.range(of: "\\b[A-Z][a-z]+\\.?\\s+$", options: .regularExpression).map({ String(before[$0]) }) else { return name }
        let word = title.trimmingCharacters(in: .whitespaces)
        guard CharacterRulesKnobs.titles.contains(word.lowercased().trimmingCharacters(in: ["."])) else { return name }
        return "\(word) \(name)"
    }

    private func taggedNames(in text: String) -> [(String, Int)] {
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        let whole = text.startIndex..<text.endIndex
        tagger.setLanguage(.english, range: whole)
        var names: [(String, Int)] = []
        tagger.enumerateTags(in: whole, unit: .word, scheme: .nameType, options: [.omitPunctuation, .omitWhitespace, .joinNames]) { tag, range in
            if tag == .personalName { names.append((String(text[range]), NSRange(range, in: text).location)) }
            return true
        }
        return names
    }

    private func capitalisedWords(in text: String) -> [(String, Int)] {
        var names: [(String, Int)] = []
        var startsSentence = true
        text.enumerateSubstrings(in: text.startIndex..<text.endIndex, options: .byWords) { word, range, enclosing, _ in
            guard let word else { return }
            // Right after an opening quote is the start of what someone says: “Good gracious…”
            let afterQuote = text[..<range.lowerBound].last { !$0.isWhitespace }.map { "“‘\"(—".contains($0) } ?? false
            if word.first?.isUppercase == true, !startsSentence, !afterQuote {
                names.append((word, NSRange(range, in: text).location))
            }
            // The full stop after "Mr" doesn't end a sentence.
            let after = text[range.upperBound..<enclosing.upperBound]
            startsSentence = after.contains { ".!?\n".contains($0) } && !CharacterRulesKnobs.titles.contains(word.lowercased())
        }
        return names
    }

    private func position(ofChapterOffset offset: Int, in chapter: Chapter, of content: BookContent) -> ReadingPosition {
        let paragraph = chapter.paragraphs.last { content.paragraphs[$0].range.location <= offset } ?? chapter.paragraphs.lowerBound
        return ReadingPosition(paragraph: paragraph, charOffset: offset - content.paragraphs[paragraph].range.location)
    }

    private static func englishModelsInstalled() -> Bool {
        let probe = "John walked to London."
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = probe
        tagger.setLanguage(.english, range: probe.startIndex..<probe.endIndex)
        return tagger.tag(at: probe.startIndex, unit: .word, scheme: .nameType).0 == .personalName
    }
}
