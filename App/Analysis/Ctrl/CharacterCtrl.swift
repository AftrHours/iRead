import Foundation

/// Names from `NameSvc`, each with the engine underline whose passage describes them best.
actor CharacterCtrl {
    private let bookID: UUID
    private let bookContentRepo: BookContentRepo
    private let underlineRepo: UnderlineRepo
    private let nameSvc: NameSvc
    private var namesByChapter: [Int: [NameMention]] = [:]

    init(bookID: UUID, bookContentRepo: BookContentRepo, underlineRepo: UnderlineRepo, nameSvc: NameSvc = NameSvc()) {
        self.bookID = bookID
        self.bookContentRepo = bookContentRepo
        self.underlineRepo = underlineRepo
        self.nameSvc = nameSvc
    }

    /// From the first chapter to the end of `page`, so nothing ahead is given away.
    func characters(through page: Page) async throws -> [BookCharacter] {
        let content = try await bookContentRepo.content(for: bookID)
        let end = endPosition(of: page, in: content)
        let firstChapter = min(content.firstReadableChapterIndex, page.chapterIndex)
        var mentions: [NameMention] = []
        for chapter in firstChapter...page.chapterIndex {
            try Task.checkCancellation()
            mentions += names(inChapter: chapter, of: content).filter { $0.position < end }
        }
        let underlines = await underlineRepo.underlines(throughChapter: page.chapterIndex, of: content)
            .filter { ReadingPosition(paragraph: $0.paragraph, charOffset: $0.range.location) < end }
        return CharacterRules.characters(from: mentions, underlines: underlines)
    }

    private func names(inChapter index: Int, of content: BookContent) -> [NameMention] {
        if let names = namesByChapter[index] { return names }
        let names = nameSvc.names(inChapter: index, of: content)
        namesByChapter[index] = names
        return names
    }

    private func endPosition(of page: Page, in content: BookContent) -> ReadingPosition {
        let chapter = content.chapters[page.chapterIndex]
        let offset = NSMaxRange(page.range)
        let paragraph = chapter.paragraphs.last { content.paragraphs[$0].range.location < offset } ?? chapter.paragraphs.lowerBound
        return ReadingPosition(paragraph: paragraph, charOffset: offset - content.paragraphs[paragraph].range.location)
    }
}
