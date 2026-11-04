import Foundation
import Testing
@testable import iRead

@Suite("ProgRepo")
struct ProgRepoTests {
    private let folder = TempFolder()
    private let bookID = UUID()

    private func expectSame(_ lhs: ReadingProgress?, _ rhs: ReadingProgress, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(lhs?.bookID == rhs.bookID, sourceLocation: sourceLocation)
        #expect(lhs?.position == rhs.position, sourceLocation: sourceLocation)
        #expect(lhs?.chapterIndex == rhs.chapterIndex, sourceLocation: sourceLocation)
        #expect(lhs?.progress == rhs.progress, sourceLocation: sourceLocation)
        #expect(lhs?.lastReadAt == rhs.lastReadAt, sourceLocation: sourceLocation)
        #expect(lhs?.readingFrontier == rhs.readingFrontier, sourceLocation: sourceLocation)
        #expect(lhs?.finishedAt == rhs.finishedAt, sourceLocation: sourceLocation)
    }

    @Test("PR-08 saveNow then progress(for:) round-trips, ISO 8601 dates included")
    func roundTrip() async {
        let repo = ProgRepo(folder: folder.url)
        let saved = ReadingProgress.make(bookID: bookID, paragraph: 7, charOffset: 12, chapterIndex: 1, progress: 0.25,
                                         readingFrontier: 30, finishedAt: Date(timeIntervalSince1970: 1_700_000_100))
        await repo.saveNow(saved)
        expectSame(await repo.progress(for: bookID), saved)
    }

    @Test("PR-09 quick saves leave the last one on disk")
    func quickSaves() async {
        let repo = ProgRepo(folder: folder.url)
        for progress in [0.1, 0.2, 0.3] {
            await repo.save(.make(bookID: bookID, progress: progress))
        }
        #expect(await eventually { await repo.progress(for: bookID)?.progress == 0.3 })
        // Give any older write a chance to land, then check it didn't replace the newest.
        try? await Task.sleep(for: .milliseconds(100))
        #expect(await repo.progress(for: bookID)?.progress == 0.3)
    }

    @Test("PR-10 setFinished sets and clears finishedAt and keeps the position")
    func setFinished() async throws {
        let repo = ProgRepo(folder: folder.url)
        await repo.saveNow(.make(bookID: bookID, paragraph: 120, progress: 0.5))

        await repo.setFinished(true, for: bookID)
        let finished = try #require(await repo.progress(for: bookID))
        #expect(finished.finishedAt != nil)
        #expect(finished.position.paragraph == 120)

        await repo.setFinished(false, for: bookID)
        let reading = try #require(await repo.progress(for: bookID))
        #expect(reading.finishedAt == nil)
        #expect(reading.position.paragraph == 120)
    }

    @Test("PR-11 resetProgress saves a 0% record and keeps lastReadAt")
    func resetProgress() async throws {
        let repo = ProgRepo(folder: folder.url)
        let readAt = Date(timeIntervalSince1970: 1_700_000_000)
        await repo.saveNow(.make(bookID: bookID, paragraph: 80, charOffset: 4, chapterIndex: 5, progress: 0.6, lastReadAt: readAt,
                                 readingFrontier: 300, finishedAt: readAt))
        await repo.resetProgress(for: bookID)
        expectSame(await repo.progress(for: bookID), .make(bookID: bookID, lastReadAt: readAt))
    }

    @Test("PR-12 an unreadable progress file reads as no progress")
    func invalidJSON() async throws {
        let file = folder.url.appending(path: "\(bookID.uuidString)/progress.json")
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("{ not json".utf8).write(to: file)
        #expect(await ProgRepo(folder: folder.url).progress(for: bookID) == nil)
    }
}
