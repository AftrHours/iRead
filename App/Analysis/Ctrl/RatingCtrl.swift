import Foundation

struct RatingCtrl {
    let bookID: UUID
    let bookTitle: String
    let bookContentRepo: BookContentRepo
    let underlineRepo: UnderlineRepo
    let ratingRepo: RatingRepo

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

    private func rating(of underline: SavedUnderline, verdict: Verdict?, in content: BookContent) -> UnderlineRating {
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
            kind: underline.kind,
            sentence: underline.sentence - firstSentence,
            sentenceText: (content.chapters[chapter].text as NSString).substring(with: sentenceRange),
            reference: underline.reference.sentence - firstSentence,
            referenceText: underline.reference.text,
            decidedBy: underline.decidedBy,
            engineVersion: UnderlineRepoKnobs.engineVersion
        )
    }
}
