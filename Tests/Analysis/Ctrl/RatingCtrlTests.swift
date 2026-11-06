import Foundation
import Testing
@testable import iRead

@Suite("RatingCtrl", .timeLimit(.minutes(1)))
struct RatingCtrlTests {
    private let folder = TempFolder()
    private let content = BookContent.make(chapters: [
        ["Then Anna saw the old clock in the hall.", "Later Anna wound the clock at noon."],
        ["A new day began with rain.", "The rain stopped by evening."]
    ])

    @Test("AN-22 a rating keeps the phrase, its sentence and the reference passage, counting sentences from the chapter's start")
    func rate() async throws {
        let rain = SavedUnderline.make("The rain", paragraph: 3, passage: "A new day began with rain.", passageParagraph: 2, in: content)
        try StoredUnderlines.write([rain], chapter: 1, of: content.fingerprint, parserVersion: content.parserVersion, in: folder.url)
        let underlineRepo = UnderlineRepo(folder: folder.url)
        // Loads the stored chapter, as showing a page of it does.
        for await _ in await underlineRepo.underline(chapter: 1, of: content, startingAt: 0) {}
        let cloud = CloudSvcFake()
        let ratingRepo = RatingRepo(folder: folder.url, cloudSvc: cloud)
        await ratingRepo.setSharesRatings(true)
        let ratingCtrl = RatingCtrl(bookID: sampleID, bookTitle: "Sample",
                                    bookContentRepo: BookContentRepo(epubParseSvc: EPUBParseSvcSpy(content: content), folder: folder.url),
                                    underlineRepo: underlineRepo, ratingRepo: ratingRepo)

        try await ratingCtrl.rate(underline: rain.id, .down)
        #expect(try await ratingCtrl.verdict(onUnderline: rain.id) == .down)
        let fields = try #require(cloud.records(in: .developers).values.first)
        #expect(fields["verdict"] == .text("down"))
        #expect(fields["bookTitle"] == .text("Sample"))
        #expect(fields["chapterIndex"] == .number(1))
        #expect(fields["phrase"] == .text("The rain"))
        #expect(fields["kind"] == .text("thing"))
        #expect(fields["sentence"] == .number(1))
        #expect(fields["sentenceText"] == .text("The rain stopped by evening."))
        #expect(fields["reference"] == .number(0))
        #expect(fields["referenceText"] == .text("A new day began with rain."))
    }

    @Test("AN-25 an underline that isn't loaded can't be rated")
    func unknownUnderline() async {
        let ratingCtrl = RatingCtrl(bookID: sampleID, bookTitle: "Sample",
                                    bookContentRepo: BookContentRepo(epubParseSvc: EPUBParseSvcSpy(content: content), folder: folder.url),
                                    underlineRepo: UnderlineRepo(folder: folder.url), ratingRepo: RatingRepo(folder: folder.url))
        await #expect(throws: ContentError.notFound) { try await ratingCtrl.rate(underline: "99:0", .up) }
    }
}
