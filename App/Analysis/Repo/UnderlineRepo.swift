import Foundation
import OSLog
import UnderlineKit

enum UnderlineRepoKnobs {
    /// The engine's own version. A chapter saved with another one is underlined again, so a new engine needs no change here.
    static let engineVersion = Underliner.releaseVersion
}

actor UnderlineRepo {
    struct StoredChapter: Codable {
        let parserVersion: Int
        /// nil in files saved before this field existed.
        let engineVersion: Int?
        let underlines: [SavedUnderline]
    }

    static let recordType = "ChapterUnderlines"
    let folder: URL
    /// Chapters worked out ahead and bundled with the app, laid out like `folder`. nil: none, as in tests.
    let seedFolder: URL?
    let logger = Logger(subsystem: Logger.appSubsystem, category: "storage")
    /// nil: no iCloud, as in tests.
    let cloudSvc: (any CloudSvc)?
    /// Makes the engine the first time a chapter needs it (the embedding may have to load). Tests pass `.testing`, which needs no download.
    let makeUnderliner: @Sendable () async -> any Underlining
    var underliner: (any Underlining)?
    var foundUnderlines: [String: [Int: [SavedUnderline]]] = [:]
    var finishedChapters: [String: Set<Int>] = [:]
    private var running: Task<Void, Never>?
    #if DEBUG
    var foundConsidered: [String: [Int: [ConsideredPhrase]]] = [:]
    var cloudResults: [String: [Int: String]] = [:]
    var bookRuns: [String: BookRun] = [:]
    var bookTask: Task<Void, Never>?
    #endif

    init(folder: URL = .applicationSupportDirectory.appending(path: "Underlines"), seedFolder: URL? = nil,
         cloudSvc: (any CloudSvc)? = nil,
         makeUnderliner: @escaping @Sendable () async -> any Underlining = { await Underliner.make(.testing) }) {
        self.folder = folder
        self.seedFolder = seedFolder
        self.cloudSvc = cloudSvc
        self.makeUnderliner = makeUnderliner
    }

    var cloudAccount: CloudAccount? {
        get async { await cloudSvc?.account() }
    }

    /// One line about the engine in use, for the debug sheet.
    var engineSummary: String {
        get async { await engine().summary }
    }

    /// Underlines from `sentence` to the chapter's end, then from its start. Yields after each paragraph that adds
    /// underlines. Starting another chapter stops this one.
    func underline(chapter: Int, of content: BookContent, startingAt sentence: Int) -> AsyncStream<Void> {
        let (stream, continuation) = AsyncStream<Void>.makeStream()
        guard !isFinished(chapter, of: content.fingerprint, parserVersion: content.parserVersion) else {
            continuation.yield()
            continuation.finish()
            return stream
        }
        running?.cancel()
        let task = Task {
            await self.run(chapter, of: content, startingAt: sentence, continuation: continuation)
        }
        running = task
        continuation.onTermination = { _ in task.cancel() }
        return stream
    }

    func underlines(inChapter chapter: Int, of book: String) -> [SavedUnderline] {
        foundUnderlines[book]?[chapter] ?? []
    }

    /// For the character list. Doesn't run the engine, so unopened chapters give none.
    func underlines(throughChapter chapter: Int, of content: BookContent) -> [SavedUnderline] {
        (0...chapter).flatMap { index in
            _ = isFinished(index, of: content.fingerprint, parserVersion: content.parserVersion)
            return underlines(inChapter: index, of: content.fingerprint)
        }
    }

    func underline(withID id: String, of book: String) -> SavedUnderline? {
        foundUnderlines[book]?.values.lazy.flatMap { $0 }.first { $0.id == id }
    }

    func run(_ index: Int, of content: BookContent, startingAt sentence: Int,
             continuation: AsyncStream<Void>.Continuation) async {
        defer { continuation.finish() }
        let book = content.fingerprint
        let parserVersion = content.parserVersion
        if let stored = await cloudChapter(index, of: book, parserVersion: parserVersion) {
            guard !Task.isCancelled else { return }
            use(stored, chapter: index, of: book)
            save(stored, chapter: index, of: book)
            continuation.yield()
            return
        }
        // The engine reads the book itself and decides how: what to count over the whole book, which embedding, which method.
        #if DEBUG
        foundConsidered[book, default: [:]][index] = []
        #endif
        for await batch in await engine().underlines(inChapter: index, of: content, startingAt: sentence) {
            // A chapter stopped and started again finds some underlines twice.
            let known = Set(underlines(inChapter: index, of: book).map(\.id))
            foundUnderlines[book, default: [:]][index, default: []] += batch.underlines.filter { !known.contains($0.id) }.map(SavedUnderline.init)
            #if DEBUG
            foundConsidered[book, default: [:]][index, default: []] += batch.considered
            #endif
            if !batch.underlines.isEmpty { continuation.yield() }
        }
        guard !Task.isCancelled else { return }
        finishedChapters[book, default: []].insert(index)
        let stored = StoredChapter(parserVersion: parserVersion, engineVersion: UnderlineRepoKnobs.engineVersion,
                                   underlines: underlines(inChapter: index, of: book))
        save(stored, chapter: index, of: book)
        logger.info("Chapter \(index) saved: \(stored.underlines.count) underlines")
        // Its own task, so starting another chapter doesn't cancel the upload.
        await Task { await self.upload(stored, chapter: index, of: book) }.value
    }
}

private extension SavedUnderline {
    init(_ underline: UnderlineResult) {
        let reference = underline.reference
        self.init(id: underline.id, sentence: underline.sentence, paragraph: underline.paragraph, range: underline.range,
                  text: underline.text, kind: underline.kind, decidedBy: underline.decidedBy,
                  reference: ContextPassage(sentence: reference.sentence, paragraph: reference.paragraph, range: reference.range,
                                            text: reference.text))
    }
}
