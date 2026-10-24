import Foundation

enum MentionKnobs {
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

extension EntityResolveSvc {
    static var mentionKnobSummary: String {
        "mentions: with-phrase \(MentionKnobs.allowWithPhrase ? "on" : "off"), \(MentionKnobs.personHeads.count) heads"
    }

    func findMentions(in sentences: [NumberedSentence], tags: SentenceTags) -> [ResolvedMention] {
        sentences.flatMap { sentence -> [ResolvedMention] in
            guard tags.tokens.indices.contains(sentence.index) else { return [] }
            let tokens = tags.tokens[sentence.index]
            return (names(in: sentence, tokens: tokens) + descriptions(in: sentence, tokens: tokens)).sorted { $0.location < $1.location }
        }
    }

    private func names(in sentence: NumberedSentence, tokens: [Token]) -> [ResolvedMention] {
        var mentions: [ResolvedMention] = []
        var i = 0
        while i < tokens.count {
            guard isNameWord(tokens[i]) else { i += 1; continue }
            var j = i
            while j + 1 < tokens.count, isNameWord(tokens[j + 1]), joinsName(tokens[j], tokens[j + 1], in: sentence) { j += 1 }
            let run = Array(tokens[i...j])
            if !run.allSatisfy(isTitle) {
                mentions.append(mention(run, in: sentence, form: .name,
                                        head: Self.nameKey(run.map(\.text).joined(separator: " ")), modifiers: []))
            }
            i = j + 1
        }
        return mentions
    }

    private func joinsName(_ left: Token, _ right: Token, in sentence: NumberedSentence) -> Bool {
        let gap = textBetween(left, right, in: sentence)
        return gap == " " || (isTitle(left) && gap == ". ")
    }

    private func isTitle(_ token: Token) -> Bool {
        MentionKnobs.titles.contains(token.text.lowercased())
    }

    private func isNameWord(_ token: Token) -> Bool {
        let lower = token.text.lowercased()
        guard !MentionKnobs.groupWords.contains(lower) else { return false }
        let isFamilyName = token.text.first?.isUppercase == true && MentionKnobs.familyTerms.contains(lower)
        return token.name.map(MentionKnobs.personNameTypes.contains) == true || isFamilyName
    }

    private func descriptions(in sentence: NumberedSentence, tokens: [Token]) -> [ResolvedMention] {
        var mentions: [ResolvedMention] = []
        for i in tokens.indices where MentionKnobs.determiners.contains(tokens[i].text.lowercased()) {
            var j = i + 1
            while j < tokens.count, MentionKnobs.descriptionWordClasses.contains(tokens[j].lexicalClass) { j += 1 }
            let words = Array(tokens[(i + 1)..<j])
            guard let head = words.last, head.lexicalClass == "Noun", isPersonHead(head) else { continue }
            var modifiers = words.dropLast().map(\.lemma)
            var end = head

            if MentionKnobs.allowWithPhrase, j < tokens.count, tokens[j].text.lowercased() == "with" {
                var k = j + 1
                while k < tokens.count, k - j <= MentionKnobs.maxWithPhraseWords,
                      MentionKnobs.withPhraseWordClasses.contains(tokens[k].lexicalClass) {
                    if MentionKnobs.descriptionWordClasses.contains(tokens[k].lexicalClass) {
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

    private func isPersonHead(_ token: Token) -> Bool {
        let lower = token.text.lowercased()
        return MentionKnobs.personHeads[token.lemma] != nil && lower == token.lemma && !MentionKnobs.groupWords.contains(lower)
    }

    private func mention(_ run: [Token], in sentence: NumberedSentence, form: MentionForm, head: String, modifiers: [String]) -> ResolvedMention {
        let location = run[0].start
        let length = run[run.count - 1].start + run[run.count - 1].length - location
        let text = (sentence.text as NSString).substring(with: NSRange(location: location, length: length))
        return ResolvedMention(sentence: sentence.index, location: location, length: length, text: text, form: form,
                       head: head, modifiers: modifiers, entity: nil, decidedBy: nil)
    }

    private func textBetween(_ left: Token, _ right: Token, in sentence: NumberedSentence) -> String {
        let gapStart = left.start + left.length
        guard right.start >= gapStart else { return "" }
        return (sentence.text as NSString).substring(with: NSRange(location: gapStart, length: right.start - gapStart))
    }
}
