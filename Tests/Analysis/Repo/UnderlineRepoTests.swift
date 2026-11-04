import Foundation
import Testing
import UnderlineEngine
@testable import iRead

@Suite("UnderlineRepo", .timeLimit(.minutes(2)))
struct UnderlineRepoTests {
    private let folder = TempFolder()
    private let bookID = UUID()
    private let content = BookContent.make(chapters: [
        ["Anna opened the old box. Inside lay a silver key.", "She took the key to the door.", "The key turned, and the door opened."],
        (1...3).map { "In room \($0) Anna found another locked door, and the silver key opened it as well." }
    ])
    /// Text the engine could never find, to tell a stored chapter from one underlined again.
    private let marker = Underline(sentence: 0, paragraph: 0, range: NSRange(location: 0, length: 4), text: "marker", kind: .thing, role: nil,
                                   reference: AnswerPassage(sentence: 0, paragraph: 0, range: NSRange(location: 0, length: 4), text: "marker"),
                                   decidedBy: .rules)

    private func storedFileExists(chapter: Int) -> Bool {
        FileManager.default.fileExists(atPath: StoredUnderlines.url(chapter: chapter, of: bookID, in: folder.url).path)
    }

    private func underline(_ chapter: Int, in repo: UnderlineRepo) async -> AsyncStream<Void> {
        await repo.underline(ChapterInputMapper.input(chapter: chapter, in: content), of: bookID, parserVersion: content.parserVersion,
                             startingAt: content.sentences.firstIndex { content.paragraphs[$0.paragraph].chapterIndex == chapter } ?? 0)
    }

    @Test("AN-03 a finished chapter loads from disk in a new repo, without running the engine")
    func finishedChapterLoads() async throws {
        for await _ in await underline(0, in: UnderlineRepo(folder: folder.url)) {}
        #expect(storedFileExists(chapter: 0))

        try StoredUnderlines.write([marker], chapter: 0, of: bookID, parserVersion: content.parserVersion, in: folder.url)
        let repo = UnderlineRepo(folder: folder.url)
        var updates = 0
        for await _ in await underline(0, in: repo) {
            updates += 1
        }
        #expect(updates == 1)
        #expect(await repo.underlines(inChapter: 0, of: bookID) == [marker])
    }

    @Test("AN-04 a chapter stored by an older parser is underlined again")
    func olderParserVersion() async throws {
        try StoredUnderlines.write([marker], chapter: 0, of: bookID, parserVersion: content.parserVersion - 1, in: folder.url)
        let repo = UnderlineRepo(folder: folder.url)
        for await _ in await underline(0, in: repo) {}
        #expect(await !repo.underlines(inChapter: 0, of: bookID).contains(marker))
        #expect(try StoredUnderlines.read(chapter: 0, of: bookID, in: folder.url).parserVersion == content.parserVersion)
    }

    @Test("AN-05 a chapter stopped part way isn't saved, and restarting it adds no duplicates")
    func stopAndRestart() async {
        let repo = UnderlineRepo(folder: folder.url)
        let stopped = await underline(1, in: repo)
        for await _ in await underline(0, in: repo) {}
        for await _ in stopped {}
        #expect(!storedFileExists(chapter: 1))

        for await _ in await underline(1, in: repo) {}
        #expect(storedFileExists(chapter: 1))
        let ids = await repo.underlines(inChapter: 1, of: bookID).map(\.id)
        #expect(Set(ids).count == ids.count)
    }
}
