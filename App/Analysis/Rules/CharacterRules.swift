import Foundation

enum CharacterRulesKnobs {
    static let minMentions = 3
    /// Common English nicknames that can't be guessed from the spelling. Pet forms that can ("Johnny" for John) are found in
    /// each book (`petForms`), and two forms used with different surnames stay apart (`isSameFamily`).
    static let nicknames: [[String]] = [
        ["Margaret", "Meg", "Maggie", "Peggy", "Madge"], ["Mary", "Molly", "Polly"], ["Sarah", "Sally"], ["Frances", "Fanny"],
        ["Elizabeth", "Beth", "Bess", "Betsy", "Betty", "Eliza", "Lizzie", "Lizzy", "Liz"], ["Susan", "Sue", "Susie"],
        ["Catherine", "Kate", "Katie", "Kitty", "Cathy"], ["Katherine", "Kate", "Katie", "Kitty", "Kathy"], ["Jane", "Jenny", "Janie"],
        ["Eleanor", "Ellen", "Nell", "Nelly"], ["Anne", "Ann", "Anna", "Annie", "Nan"], ["Dorothy", "Dolly", "Dot"],
        ["Martha", "Patty", "Mattie"], ["Isabella", "Bella", "Isabel"], ["Rebecca", "Becky"], ["Abigail", "Abby", "Nabby"],
        ["Harriet", "Hattie"], ["Josephine", "Jo", "Josie"], ["Laurence", "Laurie", "Lawrence", "Larry"],
        ["William", "Will", "Bill", "Billy", "Willie"], ["Robert", "Rob", "Bob", "Bobby"], ["Richard", "Dick", "Rick"], ["Thomas", "Tom", "Tommy"],
        ["Edward", "Ned", "Ed", "Eddie"], ["Edmund", "Ned"], ["Henry", "Harry", "Hal"], ["John", "Jack", "Johnny"],
        ["James", "Jim", "Jimmy", "Jem"], ["Theodore", "Teddy", "Theo", "Ted"], ["Charles", "Charlie", "Chas"],
        ["Frederick", "Fred", "Freddie"], ["Friedrich", "Fritz"], ["Alexander", "Alex", "Sandy"], ["Christopher", "Chris", "Kit"],
        ["Patrick", "Paddy", "Pat"], ["Philip", "Phil", "Pip"], ["Augustus", "Gus"], ["Benjamin", "Ben"], ["Samuel", "Sam", "Sammy"],
        ["Joseph", "Joe", "Joey"], ["Anthony", "Tony"], ["Andrew", "Andy"], ["Nicholas", "Nick"], ["Michael", "Mike", "Mickey"],
        ["Daniel", "Dan", "Danny"], ["Peter", "Pete"], ["Matthew", "Matt"]
    ]
    /// Followed by a surname: "Mr. Laurence". The other titles can take a first name too: "Miss Jo", "Aunt March".
    static let surnameTitles: Set<String> = ["mr", "mrs", "ms", "dr", "captain", "professor"]
    /// "Mr. Laurence" stays apart from "Laurence".
    static let titles: Set<String> = [
        "mr", "mrs", "miss", "ms", "dr", "aunt", "uncle", "sir", "lady", "lord", "madam", "madame", "captain", "professor", "father",
        "mother", "master", "mistress", "monsieur", "mademoiselle", "count", "countess", "major", "colonel", "general", "king", "queen",
        "prince", "princess", "duke", "baron", "st", "saint", "doctor"
    ]
    static let notNames: Set<String> = [
        "i", "oh", "ah", "yes", "no", "well", "dear", "god", "christmas", "sunday", "monday", "tuesday", "wednesday", "thursday",
        "friday", "saturday", "january", "february", "april", "june", "july", "august", "september", "october", "november",
        "december", "english", "french", "german", "chapter", "heaven", "lord", "mr", "mrs", "miss",
        "father", "mother", "papa", "mamma", "mama", "grandpa", "grandma", "aunt", "uncle", "sister", "brother", "sir", "madam",
        // Small words a capitalised-word fallback picks up after a quote.
        "the", "a", "an", "and", "but", "or", "if", "it", "he", "she", "we", "they", "you", "my", "his", "her", "our", "your", "their",
        "this", "that", "there", "what", "when", "why", "how", "then", "now", "here"
    ]
    /// Before a place: "in Washington", "to Italy". A person has these too ("said to Jo"), but also "said Jo".
    static let placeWords = "in|at|near|into|through|across|towards|toward|from|about|to"
    /// "A Washington hospital", "their Washington correspondence": a name used as a describing word is a place or a thing.
    static let determiners = "a|an|the|their|his|her|our|my|your|its"
    /// Next to a person's name: "said Jo", "Laurie laughed".
    static let personVerbs = "said|asked|cried|replied|answered|exclaimed|whispered|laughed|added|returned|began|smiled|thought|nodded"
    /// A first name and surname: "Josie Pye", "Catherine de Bourgh".
    /// The surname is looked ahead for, so "Lady Catherine de Bourgh" gives both "Lady Catherine" and "Catherine de Bourgh".
    static let fullName = try? NSRegularExpression(pattern: "\\b([A-Z][a-z]+)(?=\\s+(?:(?:de|van|von|du|le|la)\\s+)?([A-Z][a-z]+)\\b)")
    /// From this length, one typo is forgiven ("Lauire").
    static let typoQueryLength = 4
    /// The book saying two names are one person: "Elizabeth, or Beth, as everyone called her",
    /// "My first name is Theodore… so I made them say Laurie instead".
    static let sameNamePatterns: [NSRegularExpression] = [
        "\\b([A-Z][a-z]+), or ([A-Z][a-z]+), as \\w+ (?:called|calls|call) (?:her|him)\\b",
        "\\bname is ([A-Z][a-z]+)\\b[^.!?]*\\b(?:say|call me)\\s+([A-Z][a-z]+)\\s+instead\\b",
        "\\b([A-Z][a-z]+), (?:whom|who) (?:everyone|everybody|they|we) called ([A-Z][a-z]+)\\b",
        "\\b([A-Z][a-z]+), (?:known as|nicknamed) ([A-Z][a-z]+)\\b",
        "\\b([A-Z][a-z]+), (?:but|though) (?:everyone|everybody|they|we|she|he) called (?:her|him) ([A-Z][a-z]+)\\b",
        "\\b([A-Z][a-z]+) (?:is|was) short for ([A-Z][a-z]+)\\b"
    ].compactMap { try? NSRegularExpression(pattern: $0) }
}

enum CharacterRules {
    private struct Found {
        let person: DescriptionRules.Person
        let names: [String]
        let passage: ContextPassage?
        let lastMention: ReadingPosition
    }

    /// Most recently mentioned first, each with the passage that describes them (`DescriptionRules`).
    /// `sentences` are the book's, in reading order, up to where the reader is.
    static func characters(from mentions: [NameMention], sentences: [ContextPassage]) -> [BookCharacter] {
        let cleaned = mentions.compactMap { mention in cleanName(mention.name).map { NameMention(name: $0, position: mention.position) } }
        let counts = Dictionary(cleaned.map { ($0.name, 1) }, uniquingKeysWith: +)
        let pairs = sameNames(in: sentences)
        let bookNames = Set(pairs.flatMap { [$0.0.lowercased(), $0.1.lowercased()] })
        let surnames = surnameOwners(counts: counts, bookNames: bookNames)
        let key = keys(for: Set(counts.keys), surnames: surnames, pairs: pairs, bookNames: bookNames,
                       nicknames: nicknameJoins(counts: counts, sentences: sentences))
        let sentencesByWord = capitalisedWordIndex(of: sentences)
        let wordCase = wordCaseCounts(in: sentences)
        let narration = DescriptionRules.narration(of: sentences)
        // Words of names that aren't ordinary words, and titles: they can stand next to a name ("Jo March", "Mr. Brooke").
        let knownWords = Set(counts.keys.flatMap(words(of:)).filter { word in
            isTitle(word) || wordCase[word.lowercased()].map { $0.lower < $0.capital } ?? true
        })
        let groups = Dictionary(grouping: cleaned.compactMap { mention in key(mention.name).map { ($0, mention) } }, by: \.0)
            .mapValues { $0.map(\.1) }
            .filter { $0.value.count >= CharacterRulesKnobs.minMentions }
            .filter { isPerson(Set($0.value.map(\.name)), wordCase: wordCase, sentences: sentences, narration: narration,
                               sentencesByWord: sentencesByWord, knownWords: knownWords) }
        let allNames = Set(groups.values.flatMap { $0.map(\.name) })

        var people: [Found] = []
        for (groupKey, mentions) in groups {
            let names = mostUsedFirst(mentions.map(\.name))
            let aliases = aliases(of: names)
            // By the names in the text, not the mentions: the name finder can miss one.
            let candidates = Set(aliases.flatMap { sentencesByWord[words(of: $0).first ?? $0] ?? [] }).sorted()
            let others = allNames.subtracting(names)
            let gender = DescriptionRules.gender(of: aliases, at: candidates, in: sentences, otherNames: others)
            let passage = DescriptionRules.bestDescription(of: aliases, at: candidates, in: sentences, otherNames: others, gender: gender,
                                                           narration: narration)
            let person = DescriptionRules.Person(key: groupKey, aliases: aliases, surnames: aliases.filter { surnames[$0.lowercased()] != nil },
                                                 gender: gender)
            people.append(Found(person: person, names: names, passage: passage,
                                lastMention: mentions.map(\.position).max() ?? ReadingPosition(paragraph: 0, charOffset: 0)))
        }
        let unnamed = DescriptionRules.unnamedDescriptions(in: sentences, people: people.map(\.person), allNames: allNames)

        var found: [(character: BookCharacter, lastMention: ReadingPosition)] = []
        for entry in people {
            let passage = entry.passage ?? unnamed[entry.person.key]
            let isTitled = words(of: entry.person.key).first.map(isTitle) ?? false
            let shown = isTitled ? entry.names : entry.names.filter { words(of: $0).first.map { !isTitle($0) } ?? true }
            let name = displayName(of: shown.isEmpty ? entry.names : shown)
            found.append((BookCharacter(name: name, names: entry.names, passage: passage), entry.lastMention))
        }
        found.sort { lhs, rhs in
            lhs.lastMention != rhs.lastMention ? lhs.lastMention > rhs.lastMention : lhs.character.name < rhs.character.name
        }
        return found.map(\.character)
    }

    /// The sentences each capitalised word appears in.
    private static func capitalisedWordIndex(of sentences: [ContextPassage]) -> [String: [Int]] {
        var index: [String: [Int]] = [:]
        for (number, sentence) in sentences.enumerated() {
            let words = Set(sentence.text.split { !$0.isLetter }.filter { $0.first?.isUppercase == true }.map(String.init))
            for word in words { index[word, default: []].append(number) }
        }
        return index
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

    static func words(of name: String) -> [String] {
        name.split { $0 == " " || $0 == "." }.map(String.init)
    }

    static func isTitle(_ word: String) -> Bool {
        CharacterRulesKnobs.titles.contains(word.lowercased())
    }

    /// First names: in the nickname table, first in an untitled full name ("Jo March"), or used alone and never after
    /// Mr. or Mrs. nor after two different titles ("Lydia", but not "Bingley" or "Lucas": Lady Lucas, Miss Lucas).
    private static func givenNames(in names: Set<String>) -> Set<String> {
        let parts = names.map(words(of:))
        let firstWords = parts.filter { $0.count > 1 && !isTitle($0[0]) }.map { $0[0].lowercased() }
        var titlesBefore: [String: Set<String>] = [:]
        for name in parts where name.count > 1 && isTitle(name[0]) {
            if let last = name.last?.lowercased() { titlesBefore[last, default: []].insert(name[0].lowercased()) }
        }
        let familyNames = Set(titlesBefore.filter { _, titles in
            titles.count > 1 || !titles.isDisjoint(with: CharacterRulesKnobs.surnameTitles)
        }.keys)
        let alone = parts.filter { $0.count == 1 }.map { $0[0].lowercased() }.filter { !familyNames.contains($0) }
        return Set(firstWords).union(alone).union(formalName.keys)
    }

    /// A titled first name ("Miss Jo", or "Mr. Theodore" when the book says Theodore is a first name) is that person;
    /// any other titled name keeps its title.
    private static func isTitledFirstName(_ parts: [String], givenNames: Set<String>, bookNames: Set<String>) -> Bool {
        guard parts.count == 2 else { return false }
        let word = parts[1].lowercased()
        return bookNames.contains(word) || !CharacterRulesKnobs.surnameTitles.contains(parts[0].lowercased()) && givenNames.contains(word)
    }

    /// "laurence" → the titled names that end with it ("mr laurence"). Not a word used alone at least twice as often as with a
    /// title: that's a first name ("John", even with "Mrs. John").
    private static func surnameOwners(counts: [String: Int], bookNames: Set<String>) -> [String: Set<String>] {
        let given = givenNames(in: Set(counts.keys))
        var owners: [String: Set<String>] = [:]
        var titledCounts: [String: Int] = [:]
        for (name, count) in counts {
            let parts = words(of: name)
            guard parts.count > 1, isTitle(parts[0]), !isTitledFirstName(parts, givenNames: given, bookNames: bookNames),
                  let surname = parts.last else { continue }
            owners[surname.lowercased(), default: []].insert(parts.joined(separator: " ").lowercased())
            titledCounts[surname.lowercased(), default: 0] += count
        }
        let bare = Dictionary(counts.filter { words(of: $0.key).count == 1 }.map { ($0.key.lowercased(), $0.value) }, uniquingKeysWith: +)
        return owners.filter { surname, _ in bare[surname, default: 0] < 2 * titledCounts[surname, default: 0] }
    }

    /// Same key, same person. A titled name ("Mr. Laurence") keeps its title. A bare surname joins the one titled person
    /// with it, or is left out when several share it ("March": Mrs. March and Aunt March). Names the book says are one
    /// person are joined.
    private static func keys(for names: Set<String>, surnames: [String: Set<String>], pairs: [(String, String)],
                             bookNames: Set<String>, nicknames: [String: String]) -> (String) -> String? {
        let given = givenNames(in: names)
        func baseKey(_ name: String) -> String? {
            var parts = words(of: name)
            if isTitledFirstName(parts, givenNames: given, bookNames: bookNames) { parts.removeFirst() }
            guard let first = parts.first?.lowercased() else { return nil }
            if isTitle(first) { return parts.joined(separator: " ").lowercased() }
            if parts.count == 1, let owners = surnames[first] { return owners.count == 1 ? owners.first : nil }
            return nicknames[first] ?? first
        }
        var joined: [String: String] = [:]
        func root(_ key: String) -> String {
            var key = key
            while let next = joined[key] { key = next }
            return key
        }
        for (lhs, rhs) in pairs where names.contains(lhs) && names.contains(rhs) {
            if let lhsKey = baseKey(lhs).map(root), let rhsKey = baseKey(rhs).map(root), lhsKey != rhsKey { joined[rhsKey] = lhsKey }
        }
        return { baseKey($0).map(root) }
    }

    /// A pet form whose stem is another first name in the book: "Johnny" → "John", "Tommy" → "Tom", "Bethy" → "Beth".
    static func petForms(among names: Set<String>) -> [String: String] {
        var forms: [String: String] = [:]
        for name in names {
            guard let suffix = ["ie", "y"].first(where: name.hasSuffix) else { continue }
            var stem = String(name.dropLast(suffix.count))
            if stem.count > 3, stem.last == stem.dropLast().last { stem.removeLast() }
            if stem.count >= 3, stem != name, names.contains(stem) { forms[name] = stem }
        }
        return forms
    }

    /// First name → the full name it's a nickname of in this book (`CharacterRulesKnobs.nicknames`, `petForms`). Not when the
    /// book tells them apart: different surnames ("Josie Pye", "Josephine Barry"), another nickname of the same name with a
    /// different surname (Kitty Bryant, Kate Vaughn), or a full name mostly said with a title its nickname never has
    /// ("Lady Catherine" and Kitty).
    static func nicknameJoins(counts: [String: Int], sentences: [ContextPassage]) -> [String: String] {
        let given = givenNames(in: Set(counts.keys))
        let pets = petForms(among: given)
        let surnames = surnamesInText(given: given, nameWords: Set(counts.keys.flatMap(words(of:)).map { $0.lowercased() }),
                                      sentences: sentences)
        var titled: [String: Int] = [:], bare: [String: Int] = [:]
        for (name, count) in counts {
            let parts = words(of: name).map { $0.lowercased() }
            if parts.count == 2, isTitle(parts[0]) { titled[parts[1], default: 0] += count }
            if parts.count == 1 { bare[parts[0], default: 0] += count }
        }
        let formalOf = given.reduce(into: [String: String]()) { joins, name in
            if let formal = formalName[name] ?? pets[name].map({ formalName[$0] ?? $0 }), formal != name { joins[name] = formal }
        }
        func clash(_ lhs: String, _ rhs: String) -> Bool {
            guard let lhsFamily = surnames[lhs], let rhsFamily = surnames[rhs] else { return false }
            return lhsFamily.isDisjoint(with: rhsFamily)
        }
        return formalOf.filter { name, formal in
            let titles = titled[formal, default: 0]
            let mostlyTitled = titles >= CharacterRulesKnobs.minMentions && titles > bare[formal, default: 0] && titled[name, default: 0] == 0
            let family = formalOf.filter { $0.value == formal }.map(\.key) + [formal]
            return !mostlyTitled && !family.contains { clash(name, $0) }
        }
    }

    /// First name → the surnames the book puts after it: "Josie Pye", "Catherine de Bourgh". A word that is itself followed
    /// by a surname, or is a known first name, isn't a surname ("Beth Frank", with "Frank Vaughn").
    private static func surnamesInText(given: Set<String>, nameWords: Set<String>, sentences: [ContextPassage]) -> [String: Set<String>] {
        let pairs = sentences.flatMap { sentence -> [(String, String)] in
            let text = sentence.text as NSString
            return (CharacterRulesKnobs.fullName?.matches(in: sentence.text, range: NSRange(location: 0, length: text.length)) ?? []).map {
                (text.substring(with: $0.range(at: 1)).lowercased(), text.substring(with: $0.range(at: 2)).lowercased())
            }.filter { given.contains($0.0) && nameWords.contains($0.1) }
        }
        let firstNames = Set(pairs.map(\.0)).union(formalName.keys)
        return pairs.filter { !firstNames.contains($0.1) }.reduce(into: [:]) { surnames, pair in surnames[pair.0, default: []].insert(pair.1) }
    }

    private static func sameNames(in sentences: [ContextPassage]) -> [(String, String)] {
        sentences.flatMap { sentence -> [(String, String)] in
            let text = sentence.text as NSString
            return CharacterRulesKnobs.sameNamePatterns.flatMap { pattern in
                pattern.matches(in: sentence.text, range: NSRange(location: 0, length: text.length)).map {
                    (text.substring(with: $0.range(at: 1)), text.substring(with: $0.range(at: 2)))
                }
            }
        }
    }

    private static let formalName: [String: String] = {
        var table: [String: String] = [:]
        for group in CharacterRulesKnobs.nicknames {
            for name in group where table[name.lowercased()] == nil { table[name.lowercased()] = group[0].lowercased() }
        }
        return table
    }()

    /// "Jo/Josephine March", or "Beth March" for "Beth", "Mr. Laurence" for "Laurence".
    private static func displayName(of names: [String]) -> String {
        guard let mostUsed = names.first else { return "" }
        let longest = names.max { lhs, rhs in
            (words(of: lhs).count, lhs.count) < (words(of: rhs).count, rhs.count)
        } ?? mostUsed
        if longest == mostUsed { return mostUsed }
        if longest.hasPrefix(mostUsed + " ") || longest.hasSuffix(" " + mostUsed) { return longest }
        return "\(mostUsed)/\(longest)"
    }

    private static func aliases(of names: [String]) -> Set<String> {
        var aliases = Set(names)
        for name in names {
            if let first = words(of: name).first, !isTitle(first) { aliases.insert(first) }
        }
        return aliases
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
