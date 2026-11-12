import Foundation
import Testing
@testable import iRead

@Suite("UnderlineRepo", .timeLimit(.minutes(2)))
struct UnderlineRepoTests {
    private let folder = TempFolder()
    private let content = BookContent.make(chapters: [
        ["Anna opened the old box. Inside lay a silver key.", "She took the key to the door.", "The key turned, and the door opened."],
        (1...3).map { "In room \($0) Anna found another locked door, and the silver key opened it as well." }
    ])
    private var book: String { content.fingerprint }
    /// Text the engine could never find, to tell a stored chapter from one underlined again.
    private let marker = SavedUnderline(id: "0:0", sentence: 0, paragraph: 0, range: NSRange(location: 0, length: 4), text: "marker",
                                        kind: "thing", decidedBy: "rules",
                                        reference: ContextPassage(sentence: 0, paragraph: 0, range: NSRange(location: 0, length: 4),
                                                                  text: "marker"))

    private func storedFileExists(chapter: Int) -> Bool {
        FileManager.default.fileExists(atPath: StoredUnderlines.url(chapter: chapter, of: book, in: folder.url).path)
    }

    private func underline(_ chapter: Int, in repo: UnderlineRepo) async -> AsyncStream<Void> {
        await repo.underline(chapter: chapter, of: content,
                             startingAt: content.sentences.firstIndex { content.paragraphs[$0.paragraph].chapterIndex == chapter } ?? 0)
    }

    @Test("AN-03 a finished chapter loads from disk in a new repo, without running the engine")
    func finishedChapterLoads() async throws {
        for await _ in await underline(0, in: UnderlineRepo(folder: folder.url)) {}
        #expect(storedFileExists(chapter: 0))

        try StoredUnderlines.write([marker], chapter: 0, of: book, parserVersion: content.parserVersion, in: folder.url)
        let repo = UnderlineRepo(folder: folder.url)
        var updates = 0
        for await _ in await underline(0, in: repo) {
            updates += 1
        }
        #expect(updates == 1)
        #expect(await repo.underlines(inChapter: 0, of: book) == [marker])
    }

    @Test("AN-04 a chapter stored by an older parser is underlined again")
    func olderParserVersion() async throws {
        try StoredUnderlines.write([marker], chapter: 0, of: book, parserVersion: content.parserVersion - 1, in: folder.url)
        let repo = UnderlineRepo(folder: folder.url)
        for await _ in await underline(0, in: repo) {}
        #expect(await !repo.underlines(inChapter: 0, of: book).contains(marker))
        #expect(try StoredUnderlines.read(chapter: 0, of: book, in: folder.url).parserVersion == content.parserVersion)
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
        let ids = await repo.underlines(inChapter: 1, of: book).map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test("AN-14 a stored chapter is reused only when it was saved by the same UnderlineEngine version",
          arguments: [(UnderlineRepoKnobs.engineVersion, true), (UnderlineRepoKnobs.engineVersion - 1, false), (nil, false)])
    func engineVersion(stored version: Int?, isReused: Bool) async throws {
        try StoredUnderlines.write([marker], chapter: 0, of: book, parserVersion: content.parserVersion, engineVersion: version, in: folder.url)
        let repo = UnderlineRepo(folder: folder.url)
        for await _ in await underline(0, in: repo) {}
        #expect(await repo.underlines(inChapter: 0, of: book).contains(marker) == isReused)
        #expect(try StoredUnderlines.read(chapter: 0, of: book, in: folder.url).engineVersion == UnderlineRepoKnobs.engineVersion)
    }

    @Test("AN-15 a chapter in the reader's iCloud is used without running the engine, and kept on the device, if the engine version matches",
          arguments: [(UnderlineRepoKnobs.engineVersion, true), (UnderlineRepoKnobs.engineVersion - 1, false)])
    func chapterFromCloud(stored version: Int, isReused: Bool) async throws {
        let cloud = CloudSvcFake()
        let file = StoredUnderlines.File(parserVersion: content.parserVersion, engineVersion: version, underlines: [marker])
        try await cloud.save(["chapter": .bytes(JSONEncoder().encode(file))], asRecord: "\(book)-0", ofType: "ChapterUnderlines", in: .reader)
        let repo = UnderlineRepo(folder: folder.url, cloudSvc: cloud)
        for await _ in await underline(0, in: repo) {}
        #expect(await repo.underlines(inChapter: 0, of: book).contains(marker) == isReused)
        #expect(try StoredUnderlines.read(chapter: 0, of: book, in: folder.url).engineVersion == UnderlineRepoKnobs.engineVersion)
        #if DEBUG
        let expected = isReused ? "Loaded from iCloud" : "Underlined here and saved to iCloud"
        #expect(await repo.cloudResult(inChapter: 0, of: book) == expected)
        #endif
    }

    @Test("AN-16 a finished chapter goes to the reader's iCloud, so another device with the same book gets its underlines")
    func chapterToCloud() async {
        let cloud = CloudSvcFake()
        let repo = UnderlineRepo(folder: folder.url, cloudSvc: cloud)
        for await _ in await underline(0, in: repo) {}
        #expect(cloud.records(in: .reader)["\(book)-0"] != nil)
        #if DEBUG
        #expect(await repo.cloudResult(inChapter: 0, of: book) == "Underlined here and saved to iCloud")
        #endif

        let otherDevice = TempFolder()
        let otherRepo = UnderlineRepo(folder: otherDevice.url, cloudSvc: cloud)
        for await _ in await underline(0, in: otherRepo) {}
        #expect(await otherRepo.underlines(inChapter: 0, of: book) == (await repo.underlines(inChapter: 0, of: book)))
    }

    @Test("AN-17 without iCloud, a chapter is still underlined and saved on the device")
    func withoutCloud() async {
        let cloud = CloudSvcFake()
        cloud.isOffline = true
        let repo = UnderlineRepo(folder: folder.url, cloudSvc: cloud)
        for await _ in await underline(0, in: repo) {}
        #expect(storedFileExists(chapter: 0))
        #if DEBUG
        #expect(await repo.cloudResult(inChapter: 0, of: book)?.hasPrefix("Underlined here, but couldn't save to iCloud") == true)
        #endif
    }

    @Test("AN-26 a chapter that comes with the app is used without running the engine or asking iCloud, if the engine version matches",
          arguments: [(UnderlineRepoKnobs.engineVersion, true), (UnderlineRepoKnobs.engineVersion - 1, false)])
    func seededChapter(stored version: Int, isReused: Bool) async throws {
        let seeds = TempFolder()
        try StoredUnderlines.write([marker], chapter: 0, of: book, parserVersion: content.parserVersion, engineVersion: version, in: seeds.url)
        let cloud = CloudSvcFake()
        let repo = UnderlineRepo(folder: folder.url, seedFolder: seeds.url, cloudSvc: cloud)
        for await _ in await underline(0, in: repo) {}
        #expect(await repo.underlines(inChapter: 0, of: book).contains(marker) == isReused)
        // A seed stays in the app; only a chapter underlined here is saved on the device and in iCloud.
        #expect(storedFileExists(chapter: 0) == !isReused)
        #expect((cloud.records(in: .reader)["\(book)-0"] != nil) == !isReused)
        #if DEBUG
        let expected = isReused ? "Comes with the app, so iCloud wasn't asked" : "Underlined here and saved to iCloud"
        #expect(await repo.cloudResult(inChapter: 0, of: book) == expected)
        #endif
    }

    @Test("AN-23 the iCloud account is reported for the reader menu: signed in, signed out, or nil without iCloud")
    func account() async {
        let cloud = CloudSvcFake()
        let repo = UnderlineRepo(folder: folder.url, cloudSvc: cloud)
        #expect(await repo.cloudAccount == .signedIn)
        cloud.isOffline = true
        #expect(await repo.cloudAccount == .signedOut)
        #expect(await UnderlineRepo(folder: folder.url).cloudAccount == nil)
    }
}

@Suite("Bundled underline seeds", .timeLimit(.minutes(2)))
struct UnderlineSeedTests {
    @Test("AN-27 every bundled seed belongs to a sample book and was made by the current parser and engine")
    func seedsAreCurrent() async throws {
        let seeds = try #require(Bundle.main.url(forResource: "UnderlineSeed", withExtension: nil))
        let manager = FileManager.default
        let books = try manager.contentsOfDirectory(at: seeds, includingPropertiesForKeys: nil)
            .filter { $0.hasDirectoryPath || (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
        #expect(!books.isEmpty)
        var samples: [String: BookContent] = [:]
        for (_, fileName) in BookRecord.samples {
            let url = try #require(Bundle.main.url(forResource: fileName, withExtension: "epub"))
            let content = try await EPUBParseSvcEPUBKit().parse(url)
            samples[content.fingerprint] = content
        }
        for book in books {
            // A fingerprint no sample has means the book's text changed, so the seed would never be found.
            let content = try #require(samples[book.lastPathComponent], "No sample book has fingerprint \(book.lastPathComponent)")
            for file in try manager.contentsOfDirectory(at: book, includingPropertiesForKeys: nil) {
                let stored = try JSONDecoder().decode(StoredUnderlines.File.self, from: Data(contentsOf: file))
                let chapter = try #require(Int(file.deletingPathExtension().lastPathComponent.replacingOccurrences(of: "chapter-", with: "")))
                #expect(content.chapters.indices.contains(chapter), "\(file.lastPathComponent) is past the book's last chapter")
                #expect(stored.parserVersion == content.parserVersion, "\(file.lastPathComponent) is from another parser")
                #expect(stored.engineVersion == UnderlineRepoKnobs.engineVersion, "\(file.lastPathComponent) is from another engine")
            }
        }
    }
}
