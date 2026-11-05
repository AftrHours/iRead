import Foundation
import UnderlineEngine

struct RefCtrl {
    let bookID: UUID
    let bookContentRepo: BookContentRepo
    let underlineRepo: UnderlineRepo

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

    func marks(on page: Page, highlighting underlineID: String?) async throws -> [Mark] {
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

    private func pageRange(paragraph: Int, range: NSRange, on page: Page, in content: BookContent) -> NSRange? {
        guard content.paragraphs[paragraph].chapterIndex == page.chapterIndex else { return nil }
        let chapterRange = NSRange(location: content.paragraphs[paragraph].range.location + range.location, length: range.length)
        let visibleRange = NSIntersectionRange(chapterRange, page.range)
        guard visibleRange.length > 0 else { return nil }
        return NSRange(location: visibleRange.location - page.range.location, length: visibleRange.length)
    }
}
