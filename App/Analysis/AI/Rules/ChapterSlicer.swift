import Foundation

enum ChapterSlicerKnobs {
    static let charactersPerToken = 3
}

enum ChapterSlicer {
    static func slices(_ sentences: [NumberedSentence], maxCharacters: Int) -> [[NumberedSentence]] {
        var slices: [[NumberedSentence]] = []
        var current: [NumberedSentence] = []
        var size = 0
        for sentence in sentences {
            if !current.isEmpty, size + sentence.text.count > maxCharacters {
                slices.append(current)
                current = []
                size = 0
            }
            current.append(sentence)
            size += sentence.text.count
        }
        if !current.isEmpty { slices.append(current) }
        return slices
    }
}
