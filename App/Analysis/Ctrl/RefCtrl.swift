import Foundation
import UnderlineEngine

struct RefCtrl {
    let bookID: UUID
    let bookTitle: String
    let bookContentRepo: BookContentRepo
    let underlineRepo: UnderlineRepo
    let ratingRepo: RatingRepo

    /// Underlines the page's chapter, starting at the page. Yields whenever new underlines are found.
    func underlineUpdates(from page: Page) async throws -> AsyncStream<Void> {
        let content = try await bookContentRepo.content(for: bookID)
        return await underlineRepo.underline(
            ChapterInputMapper.input(chapter: page.chapterIndex, in: content),
            of: content.fingerprint,
            parserVersion: content.parserVersion,
            startingAt: ChapterInputMapper.firstSentence(on: page, in: content)
        )
    }

    func marks(on page: Page, highlighting underlineID: String?) async throws -> [Mark] {
        let content = try await bookContentRepo.content(for: bookID)
        var marks: [Mark] = []
        for underline in await underlineRepo.underlines(inChapter: page.chapterIndex, of: content.fingerprint) {
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
        let content = try await bookContentRepo.content(for: bookID)
        guard let underline = await underlineRepo.underline(withID: id, of: content.fingerprint) else { throw ContentError.notFound }
        let reference = underline.reference
        return (underline.text, ContextPassage(paragraph: reference.paragraph, range: reference.range, text: reference.text))
    }

    func verdict(onUnderline id: String) async throws -> Verdict? {
        let content = try await bookContentRepo.content(for: bookID)
        return await ratingRepo.verdict(onUnderline: id, of: content.fingerprint)
    }

    /// `verdict: nil` takes the rating back.
    func rate(underline id: String, _ verdict: Verdict?) async throws {
        let content = try await bookContentRepo.content(for: bookID)
        guard let underline = await underlineRepo.underline(withID: id, of: content.fingerprint) else { throw ContentError.notFound }
        await ratingRepo.save(rating(of: underline, verdict: verdict, in: content))
    }

    /// nil until the reader answers.
    func sharesRatings() async -> Bool? {
        await ratingRepo.sharesRatings
    }

    func setSharesRatings(_ shares: Bool) async {
        await ratingRepo.setSharesRatings(shares)
    }

    func sendUnsentRatings() async {
        await ratingRepo.sendUnsent()
    }

    func cloudAccount() async -> CloudAccount? {
        await underlineRepo.cloudAccount
    }

    #if DEBUG
    func underlinesUseModel() async -> Bool {
        await underlineRepo.usesModel
    }

    func underlineRecords(inChapter chapter: Int) async -> [UnderlineRecord] {
        guard let content = try? await bookContentRepo.content(for: bookID) else { return [] }
        return await underlineRepo.records(inChapter: chapter, of: content.fingerprint)
    }

    func underlines(inChapter chapter: Int) async -> [Underline] {
        guard let content = try? await bookContentRepo.content(for: bookID) else { return [] }
        return await underlineRepo.underlines(inChapter: chapter, of: content.fingerprint)
    }

    func cloudResult(inChapter chapter: Int) async -> String? {
        guard let content = try? await bookContentRepo.content(for: bookID) else { return nil }
        return await underlineRepo.cloudResult(inChapter: chapter, of: content.fingerprint)
    }

    func ratingsStatus() async -> (unsent: Int, lastSend: String?) {
        (await ratingRepo.unsentCount, await ratingRepo.lastSendResult)
    }
    #endif

    private func rating(of underline: Underline, verdict: Verdict?, in content: BookContent) -> UnderlineRating {
        let chapter = content.paragraphs[underline.paragraph].chapterIndex
        let firstSentence = content.sentences.firstIndex { content.paragraphs[$0.paragraph].chapterIndex == chapter } ?? 0
        let sentence = content.sentences[underline.sentence]
        let paragraph = content.paragraphs[sentence.paragraph]
        let sentenceRange = NSRange(location: paragraph.range.location + sentence.range.location, length: sentence.range.length)
        return UnderlineRating(
            book: content.fingerprint,
            bookTitle: bookTitle,
            chapterIndex: chapter,
            underlineID: underline.id,
            verdict: verdict,
            phrase: underline.text,
            kind: underline.kind.rawValue,
            sentence: underline.sentence - firstSentence,
            sentenceText: (content.chapters[chapter].text as NSString).substring(with: sentenceRange),
            reference: underline.reference.sentence - firstSentence,
            referenceText: underline.reference.text,
            decidedBy: underline.decidedBy.rawValue,
            engineVersion: UnderlineRepoKnobs.engineVersion
        )
    }

    private func pageRange(paragraph: Int, range: NSRange, on page: Page, in content: BookContent) -> NSRange? {
        guard content.paragraphs[paragraph].chapterIndex == page.chapterIndex else { return nil }
        let chapterRange = NSRange(location: content.paragraphs[paragraph].range.location + range.location, length: range.length)
        let visibleRange = NSIntersectionRange(chapterRange, page.range)
        guard visibleRange.length > 0 else { return nil }
        return NSRange(location: visibleRange.location - page.range.location, length: visibleRange.length)
    }
}
