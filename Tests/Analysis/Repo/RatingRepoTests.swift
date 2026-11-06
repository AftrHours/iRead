import Foundation
import Testing
@testable import iRead

@Suite("RatingRepo")
struct RatingRepoTests {
    private let folder = TempFolder()
    private let cloud = CloudSvcFake()

    private func rating(_ verdict: Verdict?, id: String = "3:5") -> UnderlineRating {
        UnderlineRating(book: "book", bookTitle: "Little Women", chapterIndex: 0, underlineID: id, verdict: verdict, phrase: "rough hands",
                        kind: "feeling", sentence: 3, sentenceText: "Beth looked at her rough hands.", reference: 1,
                        referenceText: "Beth washed the dishes.", decidedBy: "rules", engineVersion: UnderlineRepoKnobs.engineVersion)
    }

    /// What the developers' database holds.
    private var sent: [[String: CloudValue]] {
        Array(cloud.records(in: .developers).values)
    }

    @Test("AN-18 a rating is kept on the device, and sent to the developers only once the reader agrees to share")
    func sendsOnceAgreed() async {
        let repo = RatingRepo(folder: folder.url, cloudSvc: cloud)
        await repo.save(rating(.up))
        #expect(await repo.verdict(onUnderline: "3:5", of: "book") == .up)
        #expect(sent.isEmpty)

        await repo.setSharesRatings(true)
        #expect(sent.count == 1)
        #expect(sent.first?["verdict"] == .text("up"))
        #expect(sent.first?["sentenceText"] == .text("Beth looked at her rough hands."))
        #expect(sent.first?["referenceText"] == .text("Beth washed the dishes."))
        #expect(await RatingRepo(folder: folder.url).verdict(onUnderline: "3:5", of: "book") == .up)
    }

    @Test("AN-19 changing a rating replaces it, and taking it back removes it from the developers' database")
    func changeAndTakeBack() async {
        let repo = RatingRepo(folder: folder.url, cloudSvc: cloud)
        await repo.setSharesRatings(true)
        await repo.save(rating(.up))
        await repo.save(rating(.down))
        #expect(sent.map { $0["verdict"] } == [.text("down")])

        await repo.save(rating(nil))
        #expect(sent.isEmpty)
        #expect(await repo.verdict(onUnderline: "3:5", of: "book") == nil)
    }

    @Test("AN-20 a rating that can't be sent (no iCloud, offline) waits, and goes on a later launch")
    func waitsUntilSent() async {
        let repo = RatingRepo(folder: folder.url, cloudSvc: cloud)
        await repo.setSharesRatings(true)
        cloud.isOffline = true
        await repo.save(rating(.up))
        cloud.isOffline = false
        #expect(sent.isEmpty)

        await RatingRepo(folder: folder.url, cloudSvc: cloud).sendUnsent()
        #expect(sent.count == 1)
    }

    @Test("AN-21 a reader who says no sends nothing, not even after turning sharing on later")
    func notShared() async {
        let repo = RatingRepo(folder: folder.url, cloudSvc: cloud)
        await repo.setSharesRatings(false)
        await repo.save(rating(.up))
        await repo.sendUnsent()
        #expect(sent.isEmpty)

        await repo.setSharesRatings(true)
        #expect(sent.isEmpty)
        await repo.save(rating(.down, id: "4:0"))
        #expect(sent.count == 1)
    }

    @Test("AN-24 a rating changed while the last one is still sending ends up in the developers' database, sent once more")
    func changedWhileSending() async {
        let slowCloud = CloudSvcFake(saveDelay: .milliseconds(200))
        let repo = RatingRepo(folder: folder.url, cloudSvc: slowCloud)
        await repo.setSharesRatings(true)
        async let first: Void = repo.save(rating(.up))
        try? await Task.sleep(for: .milliseconds(50))
        await repo.save(rating(.down))
        await first
        #expect(slowCloud.records(in: .developers).values.map { $0["verdict"] } == [.text("down")])
        #expect(await repo.unsentCount == 0)
    }
}
