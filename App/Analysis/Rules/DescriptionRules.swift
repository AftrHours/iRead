import Foundation

enum DescriptionRulesKnobs {
    static let body: Set<String> = [
        "hair", "eyes", "eye", "face", "nose", "mouth", "lips", "chin", "cheeks", "skin", "complexion", "hands", "feet", "limbs",
        "figure", "shoulders", "voice", "smile", "features", "brow", "forehead", "teeth", "beard", "moustache", "mien", "countenance",
        "freckles", "curls", "jaw", "neck", "brows", "eyebrows", "lashes", "eyelashes", "nostrils", "temples", "wrinkles", "scar",
        "whiskers", "spectacles", "frame", "build", "stature", "physique", "gait", "bearing", "expression", "visage", "physiognomy",
        "locks", "tresses", "braids", "plaits", "pigtails", "ringlets", "fingers"
    ]
    /// Half a point each: they describe rooms and gardens too.
    static let looks: Set<String> = [
        "tall", "short", "thin", "slender", "slim", "plump", "stout", "pretty", "handsome", "beautiful", "plain", "pale", "rosy",
        "fair", "dark", "brown", "blonde", "curly", "good-looking", "gentlemanlike", "ugly", "lovely", "freckled", "bald", "graceful",
        "elegant", "awkward", "lean", "gaunt", "wiry", "lanky", "bony", "burly", "portly", "sturdy", "muscular", "petite", "delicate",
        "frail", "swarthy", "ruddy", "sallow", "tanned", "sunburnt", "wrinkled", "grizzled", "auburn", "red-haired", "white-haired",
        "grey-haired", "gray-haired", "dark-haired", "fair-haired", "hook-nosed", "clean-shaven", "bearded", "homely", "comely",
        "striking", "dapper", "shabby", "untidy"
    ]
    static let traits: Set<String> = [
        "shy", "timid", "proud", "vain", "gentle", "kind", "clever", "bold", "quiet", "lively", "merry", "cheerful", "generous",
        "selfish", "lazy", "patient", "impatient", "temper", "manner", "manners", "nature", "disposition", "character", "nervous",
        "fierce", "sweet", "tomboy", "dignified", "polite", "rude", "careless", "serious", "solemn", "grave", "affectionate",
        "mischievous", "obstinate", "stubborn", "honest", "amiable", "agreeable", "disagreeable", "sensible", "silly", "reserved",
        "reserve", "haughty", "conceited", "humour", "humor", "wit", "spirits", "temperament", "playful", "intelligent", "foolish",
        "wise", "stern", "cruel", "brave", "cowardly", "curious", "loyal", "jealous", "shrewd", "cunning", "sly", "kind-hearted",
        "warm-hearted", "good-natured", "ill-natured", "good-humoured", "good-humored", "eccentric", "melancholy", "moody", "sullen",
        "gloomy", "irritable", "quick-tempered", "hot-tempered", "imaginative", "dreamy", "romantic", "talkative", "chatty",
        "taciturn", "sociable", "ambitious", "energetic", "restless", "earnest", "sincere", "frank", "pious", "superstitious",
        "prudent", "reckless", "daring", "fearless", "courageous", "modest", "humble", "arrogant", "pompous", "greedy", "miserly",
        "resolute", "determined", "eloquent", "observant", "methodical", "monomaniac"
    ]
    /// "was a rosy, smooth-haired, bright-eyed girl of thirteen"
    static let roles = "girl|boy|woman|man|lady|gentleman|child|person|servant|maid|fellow|creature|youth|widow|soldier|lad|lass|"
        + "spinster|bachelor|orphan|sailor|captain|doctor|clergyman|governess|nurse|housekeeper|merchant|farmer|detective|officer|"
        + "stranger|beauty|scholar|teacher|student"
    static let describingVerbs = "was|is|had|has|looked|seemed|became|grew|appeared|wore"
    static let ageWords = "one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|"
        + "eighteen|nineteen|twenty|thirty|forty|fifty|sixty|seventy|eighty|ninety|\\d+"
    /// A description often runs on: "…was very tall, thin, and brown… She had a decided mouth, a comical nose…"
    static let followingSentences = 2
    static let maleTitles: Set<String> = ["mr", "sir", "lord", "captain", "colonel", "uncle", "master", "father", "monsieur", "count",
                                          "duke", "prince", "king", "baron", "signor", "senor", "herr"]
    static let femaleTitles: Set<String> = ["mrs", "miss", "ms", "lady", "aunt", "madam", "madame", "mother", "mademoiselle", "countess",
                                            "duchess", "princess", "queen", "baroness", "signora", "senora", "frau", "dame", "mistress"]
    static let male: Set<String> = ["he", "him", "his", "himself", "boy", "man", "gentleman", "lad", "fellow"]
    static let female: Set<String> = ["she", "her", "hers", "herself", "girl", "woman", "lady", "lass"]
    /// A description that names no one has to be a strong one to be given to the nearest character.
    static let unnamedMinimumCues: Double = 4
    /// How far back the nearest character is looked for.
    static let lookBackSentences = 6
    static let lookBackParagraphs = 2
}

/// How novels describe a character, as rules: the name as the subject of "was" or "had" ("Fifteen-year-old Jo was very tall"),
/// looks and temperament words, an age, "a … girl", and the sentences after it that carry on about them. Lines only spoken
/// about them in dialogue don't count.
enum DescriptionRules {
    enum Gender { case male, female }

    struct Person {
        let key: String
        let aliases: Set<String>
        /// Bare surnames among the aliases: "the Laurence boy" is a family, not this person.
        let surnames: Set<String>
        let gender: Gender?
    }

    /// The passage among `candidates` (indexes into `sentences`, in reading order) that describes the person best.
    /// A tie goes to the earliest: novels describe a character when they first come in.
    static func bestDescription(of aliases: Set<String>, at candidates: [Int], in sentences: [ContextPassage],
                                otherNames: Set<String>, gender: Gender? = nil, narration: [String]? = nil) -> ContextPassage? {
        let pattern = aliases.sorted { $0.count > $1.count }.map(NSRegularExpression.escapedPattern(for:)).joined(separator: "|")
        guard !pattern.isEmpty else { return nil }
        let others = regex(for: otherNames)
        var best: (passage: ContextPassage, score: Double)?
        for index in candidates where namedOutsideDialogue(pattern, in: narration?[index] ?? withoutDialogue(sentences[index].text)) {
            let first = sentences[index]
            // Only their part of the sentence: "…Mr. Hurst, merely looked the gentleman; but his friend Mr. Darcy… tall…"
            let part = ownPart(of: first.text, pattern: pattern, others: others)
            guard !isMostlyAboutSomeoneElse(part, gender: gender) else { continue }
            var passage = first
            var cueCount = cues(in: part, about: gender)
            for next in sentences.dropFirst(index + 1).prefix(DescriptionRulesKnobs.followingSentences) {
                guard next.paragraph == first.paragraph, !pointsElsewhere(first.text, gender: gender),
                      continues(next.text, otherNames: otherNames) else { break }
                cueCount += cues(in: next.text, about: gender)
                passage = ContextPassage(sentence: first.sentence, paragraph: first.paragraph,
                                         range: NSRange(location: first.range.location, length: NSMaxRange(next.range) - first.range.location),
                                         text: passage.text + " " + next.text)
            }
            let isSubject = matches("^[^A-Za-z]*(?:[A-Z][\\w’'.-]*\\s+){0,2}(?:\(pattern))\\b(?:,[^.;!?]{0,90},)?\\s+"
                                    + "(?:\(DescriptionRulesKnobs.describingVerbs))\\b", first.text)
            let hasAge = matches("\\b\\w+-year-old\\b|\\byears old\\b|\\b(?:of|aged)\\s+(?:\(DescriptionRulesKnobs.ageWords))\\b", first.text)
            let hasRole = matches("\\b(?:was|is)\\s+an?\\s+(?:[\\w’'-]+[,\\s]+){0,5}(?:\(DescriptionRulesKnobs.roles))\\b", first.text)
            guard (isSubject && (cueCount >= 1.5 || hasAge || hasRole)) || cueCount >= 3 else { continue }
            var score = cueCount + (isSubject ? 3 : 0) + (hasAge ? 2 : 0) + (isSubject && hasRole ? 2 : 0)
            if words(in: first.text).count < 8 { score -= 2 }
            if score > best?.score ?? -.infinity { best = (passage, score) }
        }
        return best?.passage
    }

    /// From their name to the next person named, or from the start when they're named first.
    private static func ownPart(of text: String, pattern: String, others: NSRegularExpression?) -> String {
        let nsText = text as NSString
        guard let own = nsText.range(of: "\\b(?:\(pattern))\\b", options: .regularExpression).nilIfNotFound else { return text }
        let otherMatches = others?.matches(in: text, range: NSRange(location: 0, length: nsText.length)).map(\.range) ?? []
        let start = otherMatches.contains { $0.location < own.location } ? own.location : 0
        let end = otherMatches.first { $0.location > own.location }?.location ?? nsText.length
        return nsText.substring(with: NSRange(location: start, length: end - start))
    }

    /// "Mr. Darcy had at first scarcely allowed her to be pretty… the beautiful expression of her dark eyes": as many
    /// "her" as "he", so it's about her.
    private static func isMostlyAboutSomeoneElse(_ text: String, gender: Gender?) -> Bool {
        guard let gender else { return false }
        let words = words(in: text)
        let male = words.filter { ["he", "him", "his", "himself"].contains($0) }.count
        let female = words.filter { ["she", "her", "hers", "herself"].contains($0) }.count
        let (own, other) = gender == .male ? (male, female) : (female, male)
        return other >= 2 && other >= own
    }

    /// "Sir William had been delighted with him. He was quite young…": that "He" may be someone else.
    private static func pointsElsewhere(_ text: String, gender: Gender?) -> Bool {
        switch gender {
        case .male: matches("\\bhim\\b", text)
        case .female: matches("\\bher\\b(?=\\s*[.,;:!?”]|\\s+(?:and|to|in|at|by|with|for|from|again|as)\\b)", text)
        case nil: false
        }
    }

    /// From a title ("Miss Lydia", "Mr. Darcy"), else from the first "he"/"his" or "she" after their name, outside dialogue
    /// and before anyone else is named. Nil when it isn't clear.
    static func gender(of aliases: Set<String>, at candidates: [Int], in sentences: [ContextPassage],
                       otherNames: Set<String>) -> Gender? {
        let titles = Set(aliases.compactMap { $0.split { $0 == " " || $0 == "." }.first?.lowercased() })
        let isMale = !titles.isDisjoint(with: DescriptionRulesKnobs.maleTitles)
        let isFemale = !titles.isDisjoint(with: DescriptionRulesKnobs.femaleTitles)
        if isMale != isFemale { return isMale ? .male : .female }
        guard let own = regex(for: aliases) else { return nil }
        let others = regex(for: otherNames)
        var male = 0, female = 0
        for index in candidates {
            let text = sentences[index].text as NSString
            for match in own.matches(in: sentences[index].text, range: NSRange(location: 0, length: text.length)) {
                // Into the next sentence too: "Laurie didn’t laugh. He only looked down…"
                var after = text.substring(from: NSMaxRange(match.range))
                if sentences.indices.contains(index + 1), sentences[index + 1].paragraph == sentences[index].paragraph {
                    after += " " + sentences[index + 1].text
                }
                if let other = others?.firstMatch(in: after, range: NSRange(location: 0, length: (after as NSString).length)) {
                    after = (after as NSString).substring(to: other.range.location)
                }
                after = withoutDialogue(after)
                // "Him" and "her" are left out: "Laurie looked at her" is about someone else.
                let pronoun = words(in: after).first { ["he", "his", "himself", "she", "hers", "herself"].contains($0) }
                guard let pronoun else { continue }
                if DescriptionRulesKnobs.male.contains(pronoun) { male += 1 } else { female += 1 }
            }
        }
        if male >= 2, male >= 2 * female { return .male }
        if female >= 2, female >= 2 * male { return .female }
        return nil
    }

    /// Descriptions that name no one ("Curly black hair, brown skin…, for a boy"), each given to the nearest character
    /// named just before it whose gender matches. The strongest per character, a tie going to the earliest.
    static func unnamedDescriptions(in sentences: [ContextPassage], people: [Person], allNames: Set<String>) -> [String: ContextPassage] {
        guard let anyName = regex(for: allNames) else { return [:] }
        let patterns = people.compactMap { person in regex(for: person.aliases).map { (person, $0) } }
        var best: [String: (passage: ContextPassage, cues: Double)] = [:]
        for (index, sentence) in sentences.enumerated() {
            let cueCount = cues(in: sentence.text)
            guard cueCount >= DescriptionRulesKnobs.unnamedMinimumCues,
                  anyName.firstMatch(in: sentence.text, range: NSRange(location: 0, length: (sentence.text as NSString).length)) == nil,
                  let gender = describedGender(sentence.text),
                  let person = nearestPerson(before: index, in: sentences, gender: gender, patterns: patterns),
                  cueCount > best[person.key]?.cues ?? 0 else { continue }
            best[person.key] = (sentence, cueCount)
        }
        return best.mapValues(\.passage)
    }

    private static func describedGender(_ text: String) -> Gender? {
        let words = Set(words(in: text))
        let male = !words.isDisjoint(with: DescriptionRulesKnobs.male), female = !words.isDisjoint(with: DescriptionRulesKnobs.female)
        return male == female ? nil : (male ? .male : .female)
    }

    /// The character of `gender` named last in the few sentences before `index`.
    private static func nearestPerson(before index: Int, in sentences: [ContextPassage], gender: Gender,
                                      patterns: [(Person, NSRegularExpression)]) -> Person? {
        let paragraph = sentences[index].paragraph
        for earlier in sentences[..<index].suffix(DescriptionRulesKnobs.lookBackSentences).reversed() {
            guard paragraph - earlier.paragraph <= DescriptionRulesKnobs.lookBackParagraphs else { return nil }
            let text = earlier.text as NSString
            var last: (location: Int, person: Person)?
            for (person, pattern) in patterns where person.gender == gender {
                for match in pattern.matches(in: earlier.text, range: NSRange(location: 0, length: text.length)) {
                    let name = text.substring(with: match.range)
                    let after = text.substring(from: NSMaxRange(match.range))
                    if person.surnames.contains(name), after.range(of: "^[’']?\\s+[a-z]", options: .regularExpression) != nil { continue }
                    if match.range.location >= last?.location ?? -1 { last = (match.range.location, person) }
                }
            }
            if let last { return last.person }
        }
        return nil
    }

    private static func regex(for names: Set<String>) -> NSRegularExpression? {
        guard !names.isEmpty else { return nil }
        let pattern = names.sorted { $0.count > $1.count }.map(NSRegularExpression.escapedPattern(for:)).joined(separator: "|")
        return try? NSRegularExpression(pattern: "\\b(?:\(pattern))\\b")
    }

    /// Body words and temperament count 1, looks words ½. Describing a man, "her face" is someone else's, and the other way round.
    static func cues(in text: String, about gender: Gender? = nil) -> Double {
        let words = words(in: text)
        let otherPossessive = gender.map { $0 == .male ? "her" : "his" }
        return words.indices.reduce(0) { total, index in
            let word = words[index]
            if DescriptionRulesKnobs.body.contains(word) {
                let owner = words[max(0, index - 3)..<index]
                return total + (otherPossessive.map(owner.contains) == true ? 0 : 1)
            }
            if DescriptionRulesKnobs.traits.contains(word) { return total + 1 }
            return total + (DescriptionRulesKnobs.looks.contains(word) ? 0.5 : 0)
        }
    }

    /// "She had a decided mouth…", or a sentence naming no one else that still describes.
    private static func continues(_ text: String, otherNames: Set<String>) -> Bool {
        guard cues(in: text) >= 1 else { return false }
        if matches("^[^A-Za-z]*(?:She|He|Her|His)\\b", text) { return true }
        return cues(in: text) >= 2 && !otherNames.contains { matches("\\b\(NSRegularExpression.escapedPattern(for: $0))\\b", text) }
    }

    /// Named in the narration, not only in quotes or as someone else's ("Elizabeth’s intimate friend").
    private static func namedOutsideDialogue(_ pattern: String, in narration: String) -> Bool {
        matches("\\b(?:\(pattern))\\b(?![’']s)", narration)
    }

    /// Each sentence without what's said in it. Follows the quotes through the paragraph, so the middle sentence of a long
    /// speech (no quote marks of its own) is dialogue too.
    static func narration(of sentences: [ContextPassage]) -> [String] {
        var inQuote = false
        var paragraph = -1
        return sentences.map { sentence in
            if sentence.paragraph != paragraph { (inQuote, paragraph) = (false, sentence.paragraph) }
            return String(sentence.text.map { character -> Character in
                if character == "“" { inQuote = true } else if character == "”" { inQuote = false; return " " }
                return inQuote ? " " : character
            })
        }
    }

    static func withoutDialogue(_ text: String) -> String {
        text.replacingOccurrences(of: "“[^”]*”?|\"[^\"]*\"?", with: " ", options: .regularExpression)
    }

    private static func matches(_ pattern: String, _ text: String) -> Bool {
        text.range(of: pattern, options: .regularExpression) != nil
    }

    private static func words(in text: String) -> [String] {
        text.lowercased().split { !$0.isLetter && $0 != "-" }.map(String.init)
    }
}

private extension NSRange {
    var nilIfNotFound: NSRange? { location == NSNotFound ? nil : self }
}
