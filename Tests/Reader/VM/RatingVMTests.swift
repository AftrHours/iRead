import Foundation
import Testing
@testable import iRead

@Suite("RatingVM")
@MainActor
struct RatingVMTests {
    private let folder = TempFolder()
    private let content = BookContent.make(chapters: [["The old clock stood in the hall.", "Then Anna looked at the clock again."]])

    private func makeRatingVM(underline: SavedUnderline) async throws -> (RatingVM, RatingCtrl) {
        try StoredUnderlines.write([underline], chapter: 0, of: content.fingerprint, parserVersion: content.parserVersion, in: folder.url)
        let underlineRepo = UnderlineRepo(folder: folder.url)
        // Loads the stored chapter, as showing a page of it does.
        for await _ in await underlineRepo.underline(chapter: 0, of: content, startingAt: 0) {}
        let ratingCtrl = RatingCtrl(bookID: sampleID, bookTitle: "Sample",
                                    bookContentRepo: BookContentRepo(epubParseSvc: EPUBParseSvcSpy(content: content), folder: folder.url),
                                    underlineRepo: underlineRepo, ratingRepo: RatingRepo(folder: folder.url))
        return (RatingVM(ratingCtrl: ratingCtrl), ratingCtrl)
    }

    @Test("RD-29 a thumb fills in and asks once whether to share; tapping it again takes the rating back", .timeLimit(.minutes(1)))
    func thumbs() async throws {
        let underline = SavedUnderline.make("the clock", paragraph: 1, passage: "The old clock stood in the hall.", passageParagraph: 0,
                                            in: content)
        let (ratingVM, ratingCtrl) = try await makeRatingVM(underline: underline)
        func savedVerdict() async -> Verdict? {
            (try? await ratingCtrl.verdict(onUnderline: underline.id)) ?? nil
        }

        await ratingVM.cardShown(underlineID: underline.id)
        ratingVM.verdictTapped(.up)
        #expect(ratingVM.verdict == .up)
        #expect(await eventually { ratingVM.isAskingToShare })
        ratingVM.sharingChosen(false)
        #expect(!ratingVM.isAskingToShare)
        #expect(!ratingVM.sharesRatings)
        #expect(await eventually { await ratingCtrl.sharesRatings() == false })

        ratingVM.verdictTapped(.down)
        #expect(ratingVM.verdict == .down)
        #expect(await eventually { await savedVerdict() == .down })
        #expect(!ratingVM.isAskingToShare)

        ratingVM.verdictTapped(.down)
        #expect(ratingVM.verdict == nil)
        #expect(await eventually { await savedVerdict() == nil })
    }

    @Test("RD-30 showing a card again shows its saved rating, even one still being saved", .timeLimit(.minutes(1)))
    func savedVerdictShows() async throws {
        let underline = SavedUnderline.make("the clock", paragraph: 1, passage: "The old clock stood in the hall.", passageParagraph: 0,
                                            in: content)
        let (ratingVM, _) = try await makeRatingVM(underline: underline)
        await ratingVM.cardShown(underlineID: underline.id)
        ratingVM.verdictTapped(.up)

        await ratingVM.cardShown(underlineID: underline.id)
        #expect(ratingVM.verdict == .up)
    }
}
