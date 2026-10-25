import Foundation

enum MentionFinderKnobs {
    static let titles: Set<String> = ["mr.", "mr", "mrs.", "mrs", "miss", "dr.", "dr", "aunt", "uncle", "sir", "lady"]

    static let personNameTypes: Set<String> = ["PersonalName", "Capitalised"]

    static let familyTerms: Set<String> = ["father", "mother", "papa", "mama", "marmee", "grandpa", "grandma"]

    static let personHeads: [String: String] = [
        "girl": "girl", "lass": "girl", "maiden": "girl", "child": "girl",
        "man": "man", "gentleman": "man", "fellow": "man",
        "woman": "woman", "lady": "woman",
        "boy": "boy", "lad": "boy",
        "person": "person", "bookworm": "person",
    ]

    static let groupWords: Set<String> = [
        "everyone", "everybody", "nobody", "people", "girls", "boys", "sisters", "children",
        "us", "we", "they", "all", "both", "no one",
    ]

    static let determiners: Set<String> = ["a", "an", "the", "this", "that", "his", "her", "their", "our", "my", "your"]

    static let descriptionWordClasses: Set<String> = ["Adjective", "Noun"]
    static let withPhraseWordClasses: Set<String> = ["Adjective", "Noun", "Conjunction", "Determiner"]

    static let allowWithPhrase = true
    static let maxWithPhraseWords = 6
}

enum MentionFinder {
    static func mentions(in sentences: [NumberedSentence], tags: SentenceTags) -> [ResolvedMention] {
        zip(sentences, tags.tokens).flatMap { sentence, tokens in
            (names(in: sentence, tokens: tokens) + descriptions(in: sentence, tokens: tokens)).sorted { $0.location < $1.location }
        }
    }

    private static func names(in sentence: NumberedSentence, tokens: [Token]) -> [ResolvedMention] {
        var mentions: [ResolvedMention] = []
        var i = 0
        while i < tokens.count {
            guard isNameWord(tokens[i]) else { i += 1; continue }
            var j = i
            while j + 1 < tokens.count, isNameWord(tokens[j + 1]), joinsName(tokens[j], tokens[j + 1], in: sentence) { j += 1 }
            let run = Array(tokens[i...j])
            if !run.allSatisfy(isTitle) {
                mentions.append(mention(run, in: sentence, form: .name,
                                        head: NameKey.of(run.map(\.text).joined(separator: " ")), modifiers: []))
            }
            i = j + 1
        }
        return mentions
    }

    private static func joinsName(_ left: Token, _ right: Token, in sentence: NumberedSentence) -> Bool {
        let gap = textBetween(left, right, in: sentence)
        return gap == " " || (isTitle(left) && gap == ". ")
    }

    private static func isTitle(_ token: Token) -> Bool {
        MentionFinderKnobs.titles.contains(token.text.lowercased())
    }

    private static func isNameWord(_ token: Token) -> Bool {
        let lower = token.text.lowercased()
        guard !MentionFinderKnobs.groupWords.contains(lower) else { return false }
        let isFamilyName = token.text.first?.isUppercase == true && MentionFinderKnobs.familyTerms.contains(lower)
        return token.name.map(MentionFinderKnobs.personNameTypes.contains) == true || isFamilyName
    }

    private static func descriptions(in sentence: NumberedSentence, tokens: [Token]) -> [ResolvedMention] {
        var mentions: [ResolvedMention] = []
        for i in tokens.indices where MentionFinderKnobs.determiners.contains(tokens[i].text.lowercased()) {
            var j = i + 1
            while j < tokens.count, MentionFinderKnobs.descriptionWordClasses.contains(tokens[j].lexicalClass) { j += 1 }
            let words = Array(tokens[(i + 1)..<j])
            guard let head = words.last, head.lexicalClass == "Noun", isPersonHead(head) else { continue }
            var modifiers = words.dropLast().map(\.lemma)
            var end = head

            if MentionFinderKnobs.allowWithPhrase, j < tokens.count, tokens[j].text.lowercased() == "with" {
                var k = j + 1
                while k < tokens.count, k - j <= MentionFinderKnobs.maxWithPhraseWords,
                      MentionFinderKnobs.withPhraseWordClasses.contains(tokens[k].lexicalClass) {
                    if MentionFinderKnobs.descriptionWordClasses.contains(tokens[k].lexicalClass) {
                        modifiers.append(tokens[k].lemma)
                        end = tokens[k]
                    }
                    k += 1
                }
            }
            mentions.append(mention([tokens[i], end], in: sentence, form: .description, head: head.lemma, modifiers: modifiers))
        }
        return mentions
    }

    private static func isPersonHead(_ token: Token) -> Bool {
        let lower = token.text.lowercased()
        return MentionFinderKnobs.personHeads[token.lemma] != nil && lower == token.lemma && !MentionFinderKnobs.groupWords.contains(lower)
    }

    private static func mention(_ run: [Token], in sentence: NumberedSentence, form: MentionForm, head: String, modifiers: [String]) -> ResolvedMention {
        let location = run[0].start
        let length = run[run.count - 1].start + run[run.count - 1].length - location
        let text = (sentence.text as NSString).substring(with: NSRange(location: location, length: length))
        return ResolvedMention(sentence: sentence.index, location: location, length: length, text: text, form: form,
                               head: head, modifiers: modifiers, entity: nil, decidedBy: nil)
    }

    private static func textBetween(_ left: Token, _ right: Token, in sentence: NumberedSentence) -> String {
        let gapStart = left.start + left.length
        guard right.start >= gapStart else { return "" }
        return (sentence.text as NSString).substring(with: NSRange(location: gapStart, length: right.start - gapStart))
    }
}
