import Foundation

struct RefCtrl {
    let bookID: UUID
    let bookContentRepo: BookContentRepo
    let underlineRepo: UnderlineRepo

    func startUnderlines(at position: ReadingPosition) async {
        await underlineRepo.start(for: bookID, at: position)
    }

    func stopUnderlines() async {
        await underlineRepo.stop()
    }

    func focusUnderlines(at position: ReadingPosition) async {
        await underlineRepo.setFocus(position)
    }

    func underlineUpdates() async -> AsyncStream<Int> {
        await underlineRepo.updates(for: bookID)
    }

    func marks(on page: Page, highlighting underlineID: String?) async throws -> [Mark] {
        let content = try await bookContentRepo.content(for: bookID)
        var marks: [Mark] = []
        for underline in await underlineRepo.underlines(for: bookID) {
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

    func reference(forUnderline id: String) async throws -> UnderlineReference {
        guard let underline = await underlineRepo.underline(id: id, for: bookID) else { throw ContentError.notFound }
        let passage = ContextPassage(paragraph: underline.reference.paragraph, range: underline.reference.range, text: underline.reference.text)
        return UnderlineReference(phrase: underline.text, passage: passage)
    }

    #if DEBUG
    func debugReport(chapter: Int?) async -> EngineDebugReport? {
        guard let content = try? await bookContentRepo.content(for: bookID) else { return nil }
        return EngineDebugReport(
            progress: await underlineRepo.progress(for: bookID),
            underlines: await underlineRepo.underlines(for: bookID),
            dropped: await underlineRepo.droppedPhrases(for: bookID),
            content: content,
            currentChapter: chapter
        )
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
