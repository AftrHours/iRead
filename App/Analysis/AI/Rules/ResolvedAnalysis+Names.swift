import Foundation

extension ResolvedAnalysis {
    func entityKey(forName key: String) -> Int? {
        entities.first { $0.names.contains { $0.key == key } }?.key
    }

    mutating func addName(_ mention: ResolvedMention, to key: Int, at sentence: Int) {
        guard let i = entities.firstIndex(where: { $0.key == key }) else { return }
        entities[i].names.append(EntityName(text: mention.text, key: mention.head, sinceSentence: sentence))
    }
}
