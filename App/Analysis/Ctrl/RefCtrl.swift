import Foundation

struct RefCtrl {
    let bookID: UUID
    let bookContentRepo: BookContentRepo
    let underlineRepo: UnderlineRepo

    /// Underlines the page's chapter, starting at the page. Yields whenever new underlines are found.
    func underlineUpdates(from page: Page) async throws -> AsyncStream<Void> {
        let content = try await bookContentRepo.content(for: bookID)
        return await underlineRepo.underline(chapter: page.chapterIndex, of: content,
                                             startingAt: ChapterInputMapper.firstSentence(on: page, in: content))
    }

    func marks(on page: Page, highlighting underlineID: String?) async throws -> [Mark] {
        let content = try await bookContentRepo.content(for: bookID)
        var marks: [Mark] = []
        for underline in await underlineRepo.underlines(inChapter: page.chapterIndex, of: content.fingerprint) {
            if let range = pageRange(paragraph: underline.paragraph, range: underline.range, on: page, in: content) {
                marks.append(Mark(range: range, kind: .underline(id: underline.id)))
            }
        }
        // Looked up by ID, because the passage can be in an earlier chapter than its underline.
        if let underlineID, let underline = await underlineRepo.underline(withID: underlineID, of: content.fingerprint),
           let range = pageRange(paragraph: underline.reference.paragraph, range: underline.reference.range, on: page, in: content) {
            marks.append(Mark(range: range, kind: .highlight))
        }
        return marks
    }

    func underline(withID id: String) async throws -> SavedUnderline {
        let content = try await bookContentRepo.content(for: bookID)
        guard let underline = await underlineRepo.underline(withID: id, of: content.fingerprint) else { throw ContentError.notFound }
        return underline
    }

    private func pageRange(paragraph: Int, range: NSRange, on page: Page, in content: BookContent) -> NSRange? {
        guard content.paragraphs[paragraph].chapterIndex == page.chapterIndex else { return nil }
        let chapterRange = NSRange(location: content.paragraphs[paragraph].range.location + range.location, length: range.length)
        let visibleRange = NSIntersectionRange(chapterRange, page.range)
        guard visibleRange.length > 0 else { return nil }
        return NSRange(location: visibleRange.location - page.range.location, length: visibleRange.length)
    }
}
