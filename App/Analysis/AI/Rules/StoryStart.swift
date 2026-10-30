import Foundation

enum StoryStartKnobs {
    static let titleShareForContents = 0.8
    static let minContentsParagraphs = 3
}

enum StoryStart {
    static func storySentences(_ sentences: [NumberedSentence], in content: BookContent) -> [NumberedSentence] {
        let first = firstStoryChapter(in: content)
        return sentences.filter { content.paragraphs[content.sentences[$0.index].paragraph].chapterIndex >= first }
    }

    static func firstStoryChapter(in content: BookContent) -> Int {
        let titles = Set(content.chapters.map { normalized($0.title) })
        let shares = content.chapters.map { titleShare(of: $0, titles: titles, in: content) }
        guard let contents = content.chapters.indices.first(where: {
            content.chapters[$0].paragraphs.count >= StoryStartKnobs.minContentsParagraphs
                && shares[$0] >= StoryStartKnobs.titleShareForContents
        }) else { return 0 }
        return content.chapters.indices.first { $0 > contents && shares[$0] < StoryStartKnobs.titleShareForContents } ?? 0
    }

    private static func titleShare(of chapter: Chapter, titles: Set<String>, in content: BookContent) -> Double {
        guard !chapter.paragraphs.isEmpty else { return 1 }
        let text = chapter.text as NSString
        let titleParagraphs = chapter.paragraphs.filter { titles.contains(normalized(text.substring(with: content.paragraphs[$0].range))) }
        return Double(titleParagraphs.count) / Double(chapter.paragraphs.count)
    }

    private static func normalized(_ text: String) -> String {
        text.lowercased().split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
