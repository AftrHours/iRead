import Foundation

struct RefCtrl {
    let bookID: UUID
    let bookContentRepo: BookContentRepo
    let analysisRepo: AnalysisRepo

    func prepare() async {
        _ = try? await analysisRepo.analysis(for: bookID)
    }

    func refine() async {
        _ = try? await analysisRepo.refinedAnalysis(for: bookID)
    }

    func marks(on page: Page, highlighting mentionIndex: Int?, includingSymbols: Bool) async throws -> [Mark] {
        let content = try await bookContentRepo.content(for: bookID)
        let analysis = try await analysisRepo.analysis(for: bookID)
        var marks: [Mark] = []
        for (index, mention) in analysis.mentions.enumerated() {
            if mention.passage != nil, let range = pageRange(paragraph: mention.paragraph, range: mention.range, on: page, in: content) {
                marks.append(Mark(mentionIndex: index, range: range, kind: .underline))
            }
            let firstCharacter = NSRange(location: mention.range.location, length: 1)
            if includingSymbols, let entity = analysis.entities.first(where: { $0.id == mention.entityID }),
               let range = pageRange(paragraph: mention.paragraph, range: firstCharacter, on: page, in: content) {
                marks.append(Mark(mentionIndex: index, range: range, kind: .symbol(systemName: entity.symbolName, entityName: entity.name)))
            }
            if index == mentionIndex, let passage = mention.passage,
               let range = pageRange(paragraph: passage.paragraph, range: passage.range, on: page, in: content) {
                marks.append(Mark(mentionIndex: index, range: range, kind: .highlight))
            }
        }
        return marks
    }

    func entity(forMention index: Int) async throws -> Entity {
        let analysis = try await analysisRepo.analysis(for: bookID)
        let entityID = analysis.mentions[index].entityID
        guard let entity = analysis.entities.first(where: { $0.id == entityID }) else { throw ContentError.notFound }
        return entity
    }

    func passage(forMention index: Int) async throws -> ContextPassage {
        guard let passage = try await analysisRepo.analysis(for: bookID).mentions[index].passage else {
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
