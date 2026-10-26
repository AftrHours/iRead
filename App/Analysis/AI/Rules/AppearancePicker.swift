import Foundation

enum AppearanceKnobs {
    static let minWords = 3
    static let maxMentionOffset = 60
    static let singleCharacterOnly = true

    static let words: Set<String> = [
        "tall", "short", "thin", "slender", "plump", "fat", "stout", "lean", "small", "large", "big", "little", "tiny",
        "fair", "pale", "dark", "pretty", "handsome", "beautiful", "plain", "ugly", "rosy", "ruddy", "freckled", "wrinkled",
        "hair", "haired", "curls", "curly", "curling", "braid", "beard", "mustache", "whiskers", "bald",
        "eyes", "eyed", "eye", "nose", "mouth", "lips", "chin", "cheeks", "brow", "forehead", "face", "skin", "complexion",
        "hands", "feet", "shoulders", "arms", "limbs", "figure", "build", "voice",
        "blue", "brown", "gray", "grey", "black", "yellow", "golden", "red", "white", "green", "chestnut", "auburn", "blond", "blonde",
        "old", "young", "aged", "elderly", "year-old",
        "dress", "gown", "cloak", "coat", "hat", "bonnet", "apron", "robe", "wore", "dressed"
    ]
}

enum AppearancePicker {
    static func score(_ sentence: String) -> Int {
        sentence.lowercased().split { !$0.isLetter }.filter { AppearanceKnobs.words.contains(String($0)) }.count
    }

    static func passages(of key: Int, in links: [(mention: ResolvedMention, key: Int)], named: Set<Int>, content: BookContent) -> [ContextPassage] {
        let bySentence = Dictionary(grouping: links, by: \.mention.sentence)
        let sentences = Set(links.filter { $0.key == key }.map(\.mention.sentence)).sorted()
        return sentences.compactMap { index in
            let here = bySentence[index, default: []]
            let own = here.filter { $0.key == key }
            guard let first = own.map(\.mention.location).min(), first <= AppearanceKnobs.maxMentionOffset else { return nil }
            if AppearanceKnobs.singleCharacterOnly, here.contains(where: { $0.key != key && named.contains($0.key) }) { return nil }
            let sentence = content.sentences[index]
            let text = SentenceText.of(sentence, in: content)
            guard score(text) >= AppearanceKnobs.minWords else { return nil }
            return ContextPassage(paragraph: sentence.paragraph, range: sentence.range, text: text)
        }
    }

    static func best(in appearances: [ContextPassage], before position: ReadingPosition) -> ContextPassage? {
        appearances
            .filter { $0.start <= position }
            .max { (score($0.text), $0.start) < (score($1.text), $1.start) }
    }
}
