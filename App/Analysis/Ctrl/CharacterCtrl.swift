import Foundation

/// Names from `NameSvc`, each with the passage that describes them (`CharacterRules`, `DescriptionRules`).
/// An actor, so each chapter is read once per open book.
actor CharacterCtrl {
    private let bookID: UUID
    private let bookContentRepo: BookContentRepo
    private let nameSvc: NameSvc
    private var namesByChapter: [Int: [NameMention]] = [:]
    private var sentencesByChapter: [Int: [ContextPassage]] = [:]

    init(bookID: UUID, bookContentRepo: BookContentRepo, nameSvc: NameSvc = NameSvc()) {
        self.bookID = bookID
        self.bookContentRepo = bookContentRepo
        self.nameSvc = nameSvc
    }

    /// From the first chapter to the end of `page`, so nothing ahead is given away.
    func characters(through page: Page) async throws -> [BookCharacter] {
        let content = try await bookContentRepo.content(for: bookID)
        let end = endPosition(of: page, in: content)
        let firstChapter = min(content.firstReadableChapterIndex, page.chapterIndex)
        var mentions: [NameMention] = []
        var sentences: [ContextPassage] = []
        for chapter in firstChapter...page.chapterIndex where !isLicence(content.chapters[chapter]) {
            try Task.checkCancellation()
            mentions += names(inChapter: chapter, of: content).filter { $0.position < end }
            sentences += self.sentences(inChapter: chapter, of: content).filter { $0.start < end }
        }
        return CharacterRules.characters(from: mentions, sentences: sentences)
    }

    /// The Project Gutenberg licence at the end of a book.
    private func isLicence(_ chapter: Chapter) -> Bool {
        "\(chapter.title) \(chapter.text.prefix(300))".lowercased().contains("project gutenberg")
    }

    private func names(inChapter index: Int, of content: BookContent) -> [NameMention] {
        if let names = namesByChapter[index] { return names }
        let names = nameSvc.names(inChapter: index, of: content)
        namesByChapter[index] = names
        return names
    }

    private func sentences(inChapter index: Int, of content: BookContent) -> [ContextPassage] {
        if let sentences = sentencesByChapter[index] { return sentences }
        let chapter = content.chapters[index]
        let text = chapter.text as NSString
        let sentences = content.sentences.indices.compactMap { sentence -> ContextPassage? in
            let found = content.sentences[sentence]
            guard chapter.paragraphs.contains(found.paragraph) else { return nil }
            let paragraphStart = content.paragraphs[found.paragraph].range.location
            let range = NSRange(location: paragraphStart + found.range.location, length: found.range.length)
            return ContextPassage(sentence: sentence, paragraph: found.paragraph, range: found.range, text: text.substring(with: range))
        }
        sentencesByChapter[index] = sentences
        return sentences
    }

    private func endPosition(of page: Page, in content: BookContent) -> ReadingPosition {
        let chapter = content.chapters[page.chapterIndex]
        let offset = NSMaxRange(page.range)
        let paragraph = chapter.paragraphs.last { content.paragraphs[$0].range.location < offset } ?? chapter.paragraphs.lowerBound
        return ReadingPosition(paragraph: paragraph, charOffset: offset - content.paragraphs[paragraph].range.location)
    }
}
