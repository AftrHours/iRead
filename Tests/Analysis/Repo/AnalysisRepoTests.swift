import Foundation
import Testing
@testable import iRead

@Suite("AnalysisRepo and ChapterAnalysisStore", .timeLimit(.minutes(2)))
struct AnalysisRepoTests {
    private let folder = TempFolder()
    private let bookID = UUID()

    private var store: ChapterAnalysisStore {
        ChapterAnalysisStore(root: folder.url)
    }

    private func storedFile(chapter: Int) -> URL {
        folder.url.appending(path: "\(bookID.uuidString)/analysis/chapter-\(chapter).json")
    }

    /// The engine on minimal.epub with no language model. Reading the book waits until `gate` finishes,
    /// so a test can start listening before the first chapter is published.
    private func makeRepo(parser: EPUBParseSvcSpy, gate: AsyncStream<Void>) throws -> AnalysisRepo {
        let url = try Fixture.url("minimal")
        return AnalysisRepo(content: { _ in
            for await _ in gate {}
            return try await parser.parse(url)
        }, prepassSvc: BookPrepassSvc(), chapterSvc: ChapterAnalysisSvc(), store: store, makeLLM: { LLMSvcUnavailable() })
    }

    @Test("CH-23 a stored chapter loads only for the same engine and parser version; clear removes them")
    func storeVersions() throws {
        let analysis = ChapterAnalysis(chapter: 0, engineVersion: 3, parserVersion: 2, mentions: [], memory: .empty)
        try store.save(analysis, bookID: bookID)
        #expect(store.load(bookID: bookID, chapter: 0, engineVersion: 3, parserVersion: 2) != nil)
        #expect(store.load(bookID: bookID, chapter: 0, engineVersion: 4, parserVersion: 2) == nil)
        #expect(store.load(bookID: bookID, chapter: 0, engineVersion: 3, parserVersion: 1) == nil)
        try store.clear(bookID: bookID)
        #expect(!FileManager.default.fileExists(atPath: storedFile(chapter: 0).deletingLastPathComponent().path))
    }

    @Test("CH-24 with no language model, the analysis runs to the end, publishing and storing each chapter")
    func runsWithoutModel() async throws {
        let (gate, openGate) = AsyncStream<Void>.makeStream()
        let repo = try makeRepo(parser: EPUBParseSvcSpy(), gate: gate)
        await repo.startAnalysis(for: bookID)
        let updates = await repo.updates(for: bookID)
        openGate.finish()

        var chapters: [Int] = []
        for await chapter in updates {
            chapters.append(chapter)
        }
        #expect(chapters == [0, 1])
        for chapter in 0...1 {
            #expect(store.load(bookID: bookID, chapter: chapter, engineVersion: ChapterAnalysisKnobs.engineVersion, parserVersion: 1) != nil)
        }
    }

    @Test("CH-25 starting the same book twice doesn't restart it, and a later run reuses stored chapters")
    func resumes() async throws {
        let (gate, openGate) = AsyncStream<Void>.makeStream()
        let parser = EPUBParseSvcSpy()
        let repo = try makeRepo(parser: parser, gate: gate)
        await repo.startAnalysis(for: bookID)
        await repo.startAnalysis(for: bookID)
        let updates = await repo.updates(for: bookID)
        openGate.finish()
        for await _ in updates {}
        #expect(parser.parseCount == 1)

        // As if the app stopped after chapter 1.
        try FileManager.default.removeItem(at: storedFile(chapter: 1))
        let firstSaved = try FileManager.default.attributesOfItem(atPath: storedFile(chapter: 0).path)[.modificationDate] as? Date

        let (resumeGate, openResumeGate) = AsyncStream<Void>.makeStream()
        let resumed = try makeRepo(parser: EPUBParseSvcSpy(), gate: resumeGate)
        await resumed.startAnalysis(for: bookID)
        let resumedUpdates = await resumed.updates(for: bookID)
        openResumeGate.finish()
        var chapters: [Int] = []
        for await chapter in resumedUpdates {
            chapters.append(chapter)
        }
        #expect(chapters == [0, 1])
        #expect(try FileManager.default.attributesOfItem(atPath: storedFile(chapter: 0).path)[.modificationDate] as? Date == firstSaved)
        #expect(FileManager.default.fileExists(atPath: storedFile(chapter: 1).path))
    }

    @Test("CH-26 updates for a book that isn't running finish at once")
    func notRunning() async throws {
        let (gate, _) = AsyncStream<Void>.makeStream()
        var count = 0
        for await _ in try await makeRepo(parser: EPUBParseSvcSpy(), gate: gate).updates(for: bookID) {
            count += 1
        }
        #expect(count == 0)
    }

    @Test("CH-27 rules alone find the four March sisters in Little Women chapter 1, each with its own symbol",
          .tags(.golden), .timeLimit(.minutes(5)))
    func littleWomen() async throws {
        let url = try #require(Bundle.main.url(forResource: "little-women", withExtension: "epub"))
        let content = try await EPUBParseSvcEPUBKit().parse(url)
        let book = BookPrepassSvc().prepare(content)
        let result = await ChapterAnalysisSvc().analyze(chapter: book.chapters.lowerBound, book: book, memory: .empty, mentionsSoFar: [],
                                                        llm: LLMSvcUnavailable())
        let analysis = AnalysisMapper.map(memory: result.memory, mentions: result.mentions, content: content)

        var symbols: [String] = []
        for sister in ["Meg", "Jo", "Beth", "Amy"] {
            let entity = analysis.entities.first { $0.names.contains(sister) }
            #expect(entity != nil, "\(sister) not found")
            symbols += entity.map { [$0.symbolName] } ?? []
        }
        #expect(Set(symbols).count == symbols.count)
    }
}
