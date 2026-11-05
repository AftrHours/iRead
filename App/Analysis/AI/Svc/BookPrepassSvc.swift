import Foundation

struct BookPrepassSvc: Sendable {
    private let wordTagSvc = WordTagSvc()

    func prepare(_ content: BookContent) -> PreparedBook {
        let sentences = StoryStart.storySentences(SentenceText.numbered(in: content), in: content)
        let tags = wordTagSvc.tag(sentences)
        return PreparedBook(
            content: content,
            sentences: sentences,
            tags: tags,
            vocabulary: NameVocabularyBuilder.build(sentences: sentences, tags: tags),
            chapters: StoryStart.firstStoryChapter(in: content)..<content.chapters.count
        )
    }
}
