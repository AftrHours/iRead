import Foundation

struct RefCtrl {
    let bookID: UUID
    let bookContentRepo: BookContentRepo
    let analysisRepo: AnalysisRepo

    func startAnalysis() async {
        await analysisRepo.startAnalysis(for: bookID)
    }

    func stopAnalysis() async {
        await analysisRepo.stopAnalysis()
    }

    func analysisUpdates() async -> AsyncStream<Int> {
        await analysisRepo.updates(for: bookID)
    }

    func snapshot() async -> AnalysisSnapshot? {
        await analysisRepo.snapshot(for: bookID)
    }

    func progress() async -> EngineProgress? {
        await analysisRepo.progress(for: bookID)
    }

    func marks(on page: Page, highlighting mentionIndex: Int?, includingSymbols: Bool, editedSymbols: [String: SymbolStyle]) async throws -> [Mark] {
        let content = try await bookContentRepo.content(for: bookID)
        let analysis = await analysisRepo.analysis(for: bookID)
        var marks: [Mark] = []
        for (index, mention) in analysis.mentions.enumerated() {
            if mention.passage != nil, let range = pageRange(paragraph: mention.paragraph, range: mention.range, on: page, in: content) {
                marks.append(Mark(mentionIndex: index, range: range, kind: .underline))
            }
            let firstCharacter = NSRange(location: mention.range.location, length: 1)
            if includingSymbols, let entity = analysis.entities.first(where: { $0.id == mention.entityID }),
               let range = pageRange(paragraph: mention.paragraph, range: firstCharacter, on: page, in: content) {
                let style = SymbolPalette.style(for: entity, edited: editedSymbols)
                marks.append(Mark(mentionIndex: index, range: range, kind: .symbol(style, entityName: entity.name)))
            }
            if index == mentionIndex, let passage = mention.passage,
               let range = pageRange(paragraph: passage.paragraph, range: passage.range, on: page, in: content) {
                marks.append(Mark(mentionIndex: index, range: range, kind: .highlight))
            }
        }
        return marks
    }

    func entity(forMention index: Int) async throws -> Entity {
        let analysis = await analysisRepo.analysis(for: bookID)
        guard analysis.mentions.indices.contains(index) else { throw ContentError.notFound }
        let entityID = analysis.mentions[index].entityID
        guard let entity = analysis.entities.first(where: { $0.id == entityID }) else { throw ContentError.notFound }
        return entity
    }

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

    func passage(forMention index: Int) async throws -> ContextPassage {
        let analysis = await analysisRepo.analysis(for: bookID)
        guard analysis.mentions.indices.contains(index), let passage = analysis.mentions[index].passage else {
            throw ContentError.notFound
        }
        return passage
    }

    private func pageRange(paragraph: Int, range: NSRange, on page: Page, in content: BookContent) -> NSRange? {
        guard content.paragraphs[paragraph].chapterIndex == page.chapterIndex else { return nil }
        let chapterRange = NSRange(location: content.paragraphs[paragraph].range.location + range.location, length: range.length)
        let visibleRange = NSIntersectionRange(chapterRange, page.range)
        guard visibleRange.length > 0 else { return nil }
        return NSRange(location: visibleRange.location - page.range.location, length: visibleRange.length)
    }
}
