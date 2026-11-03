import Foundation
import UnderlineEngine

struct RefCtrl {
    let bookID: UUID
    let bookContentRepo: BookContentRepo
    let analysisRepo: AnalysisRepo
    let underlineRepo: UnderlineRepo

    func startAnalysis() async {
        await analysisRepo.startAnalysis(for: bookID)
    }

    func stopAnalysis() async {
        await analysisRepo.stopAnalysis()
    }

    func analysisUpdates() async -> AsyncStream<Int> {
        await analysisRepo.updates(for: bookID)
    }

    /// Underlines the page's chapter, starting at the page. Yields whenever new underlines are found.
    func underlineUpdates(from page: Page) async throws -> AsyncStream<Void> {
        let content = try await bookContentRepo.content(for: bookID)
        return await underlineRepo.underline(
            ChapterInputMapper.input(chapter: page.chapterIndex, in: content),
            of: bookID,
            parserVersion: content.parserVersion,
            startingAt: ChapterInputMapper.firstSentence(on: page, in: content)
        )
    }

    func marks(on page: Page, highlighting underlineID: String?, includingSymbols: Bool, editedSymbols: [String: SymbolStyle]) async throws -> [Mark] {
        let content = try await bookContentRepo.content(for: bookID)
        var marks: [Mark] = []
        for underline in await underlineRepo.underlines(inChapter: page.chapterIndex, of: bookID) {
            if let range = pageRange(paragraph: underline.paragraph, range: underline.range, on: page, in: content) {
                marks.append(Mark(range: range, kind: .underline(id: underline.id)))
            }
            if underline.id == underlineID,
               let range = pageRange(paragraph: underline.reference.paragraph, range: underline.reference.range, on: page, in: content) {
                marks.append(Mark(range: range, kind: .highlight))
            }
        }
        guard includingSymbols else { return marks }
        let analysis = await analysisRepo.analysis(for: bookID)
        let entities = Dictionary(uniqueKeysWithValues: analysis.entities.map { ($0.id, $0) })
        for (index, mention) in analysis.mentions.enumerated() {
            let firstCharacter = NSRange(location: mention.range.location, length: 1)
            if let entity = entities[mention.entityID], let range = pageRange(paragraph: mention.paragraph, range: firstCharacter, on: page, in: content) {
                let style = SymbolPalette.style(for: entity, edited: editedSymbols)
                marks.append(Mark(range: range, kind: .symbol(style, entityName: entity.name, mentionIndex: index)))
            }
        }
        return marks
    }

    /// The underlined phrase and the earlier passage that explains it.
    func underline(withID id: String) async throws -> (phrase: String, passage: ContextPassage) {
        guard let underline = await underlineRepo.underline(withID: id, of: bookID) else { throw ContentError.notFound }
        let reference = underline.reference
        return (underline.text, ContextPassage(paragraph: reference.paragraph, range: reference.range, text: reference.text))
    }

    #if DEBUG
    func underlinesUseModel() async -> Bool {
        await underlineRepo.usesModel
    }

    func underlineRecords(inChapter chapter: Int) async -> [UnderlineRecord] {
        await underlineRepo.records(inChapter: chapter, of: bookID)
    }

    func underlines(inChapter chapter: Int) async -> [Underline] {
        await underlineRepo.underlines(inChapter: chapter, of: bookID)
    }
    #endif

    func symbolCard(forMention index: Int) async throws -> SymbolCard {
        let analysis = await analysisRepo.analysis(for: bookID)
        guard analysis.mentions.indices.contains(index) else { throw ContentError.notFound }
        let mention = analysis.mentions[index]
        guard let entity = analysis.entities.first(where: { $0.id == mention.entityID }) else { throw ContentError.notFound }
        let position = ReadingPosition(paragraph: mention.paragraph, charOffset: mention.range.location)
        return SymbolCard(entity: entity, appearance: AppearancePicker.best(in: entity.appearances, before: position))
    }

    /// The characters mentioned in a chapter, in the order they first appear.
    func entities(inChapter chapterIndex: Int) async throws -> [Entity] {
        let content = try await bookContentRepo.content(for: bookID)
        let analysis = await analysisRepo.analysis(for: bookID)
        var entityIDs: [String] = []
        for mention in analysis.mentions
        where content.paragraphs[mention.paragraph].chapterIndex == chapterIndex && !entityIDs.contains(mention.entityID) {
            entityIDs.append(mention.entityID)
        }
        return entityIDs.compactMap { id in analysis.entities.first { $0.id == id } }
    }

    private func pageRange(paragraph: Int, range: NSRange, on page: Page, in content: BookContent) -> NSRange? {
        guard content.paragraphs[paragraph].chapterIndex == page.chapterIndex else { return nil }
        let chapterRange = NSRange(location: content.paragraphs[paragraph].range.location + range.location, length: range.length)
        let visibleRange = NSIntersectionRange(chapterRange, page.range)
        guard visibleRange.length > 0 else { return nil }
        return NSRange(location: visibleRange.location - page.range.location, length: visibleRange.length)
    }
}
