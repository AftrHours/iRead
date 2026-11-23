import Foundation

enum CharacterRulesKnobs {
    static let minMentions = 3
    static let nicknames: [[String]] = [
        ["Josephine", "Jo", "Josie"], ["Margaret", "Meg", "Maggie", "Peggy", "Madge"], ["Laurence", "Laurie", "Lawrence", "Larry"],
        ["Elizabeth", "Beth", "Bess", "Betsy", "Betty", "Eliza", "Lizzie", "Lizzy", "Liz"], ["Theodore", "Teddy", "Theo"],
        ["Catherine", "Kate", "Katie", "Kitty", "Cathy"], ["Katherine", "Kate", "Katie", "Kitty", "Kathy"], ["Mary", "Molly", "Polly"],
        ["Sarah", "Sally"], ["Frances", "Fanny"], ["Eleanor", "Ellen", "Nell", "Nelly"], ["Susan", "Sue", "Susie"],
        ["Jane", "Jenny", "Janie"], ["Anne", "Ann", "Anna", "Annie", "Nan", "Nancy"], ["William", "Will", "Bill", "Billy", "Willie"],
        ["Robert", "Rob", "Bob", "Bobby"], ["Richard", "Dick", "Rick"], ["Thomas", "Tom", "Tommy"], ["James", "Jim", "Jimmy", "Jem"],
        ["John", "Jack", "Johnny"], ["Edward", "Ned", "Ed", "Eddie"], ["Henry", "Harry", "Hal"], ["Charles", "Charlie", "Chas"],
        ["Frederick", "Fred", "Freddie", "Fritz"], ["Benjamin", "Ben"], ["Samuel", "Sam", "Sammy"], ["Joseph", "Joe", "Joey"],
        ["Anthony", "Tony"], ["Alexander", "Alex", "Sandy"], ["Andrew", "Andy"], ["Nicholas", "Nick"], ["Michael", "Mike", "Mickey"],
        ["Daniel", "Dan", "Danny"], ["Peter", "Pete"], ["Christopher", "Chris", "Kit"], ["Matthew", "Matt"]
    ]
    /// "Mr. Laurence" stays apart from "Laurence".
    static let titles: Set<String> = [
        "mr", "mrs", "miss", "ms", "dr", "aunt", "uncle", "sir", "lady", "lord", "madam", "madame", "captain", "professor", "father",
        "mother", "master", "mistress", "monsieur", "mademoiselle"
    ]
    static let notNames: Set<String> = [
        "i", "oh", "ah", "yes", "no", "well", "dear", "god", "christmas", "sunday", "monday", "tuesday", "wednesday", "thursday",
        "friday", "saturday", "january", "february", "april", "june", "july", "august", "september", "october", "november",
        "december", "english", "french", "german", "chapter", "heaven", "lord", "mr", "mrs", "miss",
        "father", "mother", "papa", "mamma", "mama", "grandpa", "grandma", "aunt", "uncle", "sister", "brother", "sir", "madam"
    ]
    static let describingKinds: Set<String> = ["thing", "person"]
    /// From this length, one typo is forgiven ("Lauire").
    static let typoQueryLength = 4
}

enum CharacterRules {
    /// Most recently mentioned first.
    static func characters(from mentions: [NameMention], underlines: [SavedUnderline]) -> [BookCharacter] {
        let cleaned = mentions.compactMap { mention in cleanName(mention.name).map { NameMention(name: $0, position: mention.position) } }
        let counts = Dictionary(cleaned.map { ($0.name, 1) }, uniquingKeysWith: +)
        let groups = Dictionary(grouping: cleaned.filter { counts[$0.name, default: 0] >= CharacterRulesKnobs.minMentions }, by: { key(of: $0.name) })
        var paragraphKeys: [Int: Set<String>] = [:]
        for mention in cleaned { paragraphKeys[mention.position.paragraph, default: []].insert(key(of: mention.name)) }

        var found: [(character: BookCharacter, lastMention: ReadingPosition)] = []
        for (key, mentions) in groups {
            let names = mostUsedFirst(mentions.map(\.name))
            let best = bestUnderline(for: key, names: names, in: underlines, paragraphKeys: paragraphKeys)
            let character = BookCharacter(name: displayName(of: names), names: names, underlineID: best?.id, passage: best?.reference.text)
            found.append((character, mentions.map(\.position).max() ?? ReadingPosition(paragraph: 0, charOffset: 0)))
        }
        found.sort { lhs, rhs in
            lhs.lastMention != rhs.lastMention ? lhs.lastMention > rhs.lastMention : lhs.character.name < rhs.character.name
        }
        return found.map(\.character)
    }

    private static func mostUsedFirst(_ names: [String]) -> [String] {
        let counts: [String: Int] = Dictionary(names.map { ($0, 1) }, uniquingKeysWith: +)
        return counts.keys.sorted { lhs, rhs in
            counts[lhs, default: 0] != counts[rhs, default: 0] ? counts[lhs, default: 0] > counts[rhs, default: 0] : lhs < rhs
        }
    }

    static func matches(_ character: BookCharacter, query: String) -> Bool {
        let query = folded(query.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !query.isEmpty else { return true }
        let names = character.names.map(folded)
        if names.contains(where: { $0.contains(query) }) { return true }
        guard query.count >= CharacterRulesKnobs.typoQueryLength else { return false }
        let words = names.flatMap { $0.split(separator: " ").map(String.init) }
        return words.contains { typos(between: query, and: String($0.prefix(query.count))) <= 1 }
    }

    private static func cleanName(_ name: String) -> String? {
        var name = name.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        for suffix in ["’s", "'s"] where name.hasSuffix(suffix) { name.removeLast(suffix.count) }
        guard name.count > 1, name.first?.isUppercase == true, name.contains(where: \.isLowercase),
              !name.hasPrefix("I’"), !name.hasPrefix("I'"),
              !CharacterRulesKnobs.notNames.contains(name.lowercased()) else { return nil }
        return name
    }

    private static func words(of name: String) -> [String] {
        name.split { $0 == " " || $0 == "." }.map(String.init)
    }

    /// Same key, same person.
    private static func key(of name: String) -> String {
        let words = words(of: name)
        guard let first = words.first?.lowercased() else { return name.lowercased() }
        if CharacterRulesKnobs.titles.contains(first) { return words.joined(separator: " ").lowercased() }
        return formalName[first] ?? first
    }

    private static let formalName: [String: String] = {
        var table: [String: String] = [:]
        for group in CharacterRulesKnobs.nicknames {
            for name in group where table[name.lowercased()] == nil { table[name.lowercased()] = group[0].lowercased() }
        }
        return table
    }()

    /// "Jo/Josephine March", or "Beth March" for "Beth".
    private static func displayName(of names: [String]) -> String {
        guard let mostUsed = names.first else { return "" }
        let longest = names.max { lhs, rhs in
            (words(of: lhs).count, lhs.count) < (words(of: rhs).count, rhs.count)
        } ?? mostUsed
        if longest == mostUsed { return mostUsed }
        if longest.hasPrefix(mostUsed + " ") { return longest }
        return "\(mostUsed)/\(longest)"
    }

    /// Name in the passage > in the phrase > nearby in either paragraph. A tie goes to the latest.
    private static func bestUnderline(for key: String, names: [String], in underlines: [SavedUnderline],
                                      paragraphKeys: [Int: Set<String>]) -> SavedUnderline? {
        let aliases = aliases(of: names)
        var best: (underline: SavedUnderline, score: Int)?
        for underline in underlines {
            var link = 0
            if containsAny(aliases, in: underline.reference.text) { link += 3 }
            if containsAny(aliases, in: underline.text) { link += 2 }
            if paragraphKeys[underline.reference.paragraph]?.contains(key) == true { link += 1 }
            if paragraphKeys[underline.paragraph]?.contains(key) == true { link += 1 }
            guard link > 0 else { continue }
            let score = link + (CharacterRulesKnobs.describingKinds.contains(underline.kind) ? 1 : 0)
            if let current = best, (current.score, current.underline.sentence) >= (score, underline.sentence) { continue }
            best = (underline, score)
        }
        return best?.underline
    }

    private static func aliases(of names: [String]) -> Set<String> {
        var aliases = Set(names)
        for name in names {
            if let first = words(of: name).first, !CharacterRulesKnobs.titles.contains(first.lowercased()) { aliases.insert(first) }
        }
        return aliases
    }

    private static func containsAny(_ words: Set<String>, in text: String) -> Bool {
        words.contains { word in
            var searchRange = text.startIndex..<text.endIndex
            while let found = text.range(of: word, range: searchRange) {
                let before = found.lowerBound == text.startIndex ? nil : text[text.index(before: found.lowerBound)]
                let after = found.upperBound == text.endIndex ? nil : text[found.upperBound]
                if before?.isLetter != true, after?.isLetter != true { return true }
                searchRange = found.upperBound..<text.endIndex
            }
            return false
        }
    }

    private static func folded(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }

    private static func typos(between lhs: String, and rhs: String) -> Int {
        let lhs = Array(lhs), rhs = Array(rhs)
        guard !lhs.isEmpty, !rhs.isEmpty else { return max(lhs.count, rhs.count) }
        var distance = Array(repeating: Array(repeating: 0, count: rhs.count + 1), count: lhs.count + 1)
        for i in 0...lhs.count { distance[i][0] = i }
        for j in 0...rhs.count { distance[0][j] = j }
        for i in 1...lhs.count {
            for j in 1...rhs.count {
                let cost = lhs[i - 1] == rhs[j - 1] ? 0 : 1
                distance[i][j] = min(distance[i - 1][j] + 1, distance[i][j - 1] + 1, distance[i - 1][j - 1] + cost)
                if i > 1, j > 1, lhs[i - 1] == rhs[j - 2], lhs[i - 2] == rhs[j - 1] {
                    distance[i][j] = min(distance[i][j], distance[i - 2][j - 2] + 1)
                }
            }
        }
        return distance[lhs.count][rhs.count]
    }
}
