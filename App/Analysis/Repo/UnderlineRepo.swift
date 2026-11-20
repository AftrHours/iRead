import Foundation
import OSLog
import UnderlineEngine

enum UnderlineRepoKnobs {
    /// 5: UnderlineEngine R8 (rules only, contextual embedding, whole-book word rarity). Chapters saved by 4 are worked out again.
    static let engineVersion = 5
    /// "Underline whole book" saves a chapter when at most this share of its phrases failed in the model (it refuses some
    /// ordinary words, like "hate"), and leaves it out when more did, so a model that isn't answering saves nothing.
    static let bookMaxFailureShare = 0.1
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
    /// nil: rules only, as in tests.
    let modelCheckSvc: ModelCheckSvc?
    /// nil: no iCloud, as in tests.
    let cloudSvc: (any CloudSvc)?
    /// `.contextual` in the app. Tests keep `.automatic` (`NLEmbedding`), which needs no download.
    let embedding: EmbeddingChoice
    var underlineCtrl: UnderlineCtrl?
    var foundUnderlines: [String: [Int: [SavedUnderline]]] = [:]
    var finishedChapters: [String: Set<Int>] = [:]
    private var running: Task<Void, Never>?
    #if DEBUG
    var foundRecords: [String: [Int: [UnderlineRecord]]] = [:]
    var cloudResults: [String: [Int: String]] = [:]
    var bookRuns: [String: BookRun] = [:]
    var bookTask: Task<Void, Never>?
    #endif

    init(folder: URL = .applicationSupportDirectory.appending(path: "Underlines"), seedFolder: URL? = nil,
         modelCheckSvc: ModelCheckSvc? = nil, cloudSvc: (any CloudSvc)? = nil, embedding: EmbeddingChoice = .automatic) {
        self.folder = folder
        self.seedFolder = seedFolder
        self.modelCheckSvc = modelCheckSvc
        self.cloudSvc = cloudSvc
        self.embedding = embedding
    }

    var cloudAccount: CloudAccount? {
        get async { await cloudSvc?.account() }
    }

    var usesModel: Bool {
        get async { await engine().usesModel }
    }

    /// The embedding the engine ended up with: contextual, or sentence when the contextual model didn't arrive in time.
    var embeddingEngine: EmbeddingEngine {
        get async { await engine().embeddingEngine }
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

    func underline(withID id: String, of book: String) -> SavedUnderline? {
        foundUnderlines[book]?.values.lazy.flatMap { $0 }.first { $0.id == id }
    }
    
    func run(_ index: Int, of content: BookContent, startingAt sentence: Int,
                     continuation: AsyncStream<Void>.Continuation, toleratesFailures: Bool = false) async {
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
        let underlineCtrl = await engine()
        // Word rarity and the embedding centre come from the whole book, worked out once per book by the engine.
        let indexed = await underlineCtrl.prepare(ChapterInputMapper.input(chapter: index, in: content), ofBook: book) {
            content.chapters.indices.map { ChapterInputMapper.input(chapter: $0, in: content) }
        }
        #if DEBUG
        foundRecords[book, default: [:]][index] = []
        #endif
        var phraseCount = 0
        var failedCount = 0
        for await result in underlineCtrl.paragraphResults(in: indexed, startingAt: sentence) {
            phraseCount += result.records.count
            failedCount += result.records.filter { $0.dropped == .modelFailed }.count
            // A chapter stopped and started again finds some underlines twice.
            let known = Set(underlines(inChapter: index, of: book).map(\.id))
            foundUnderlines[book, default: [:]][index, default: []] += result.underlines.filter { !known.contains($0.id) }.map(SavedUnderline.init)
            #if DEBUG
            foundRecords[book, default: [:]][index, default: []] += result.records
            #endif
            if !result.underlines.isEmpty { continuation.yield() }
        }
        // A model failure means missed underlines, so the chapter is tried again next time. A whole-book run accepts a few.
        let failedShare = phraseCount == 0 ? 0 : Double(failedCount) / Double(phraseCount)
        let acceptable = failedCount == 0 || (toleratesFailures && failedShare <= UnderlineRepoKnobs.bookMaxFailureShare)
        if !acceptable, !Task.isCancelled {
            logger.notice("Chapter \(index) not saved: the model failed on \(failedCount) of \(phraseCount) phrases")
        }
        guard !Task.isCancelled, acceptable else { return }
        #if DEBUG
        if toleratesFailures { bookRuns[book]?.skippedPhrases += failedCount }
        #endif
        finishedChapters[book, default: []].insert(index)
        let stored = StoredChapter(parserVersion: parserVersion, engineVersion: UnderlineRepoKnobs.engineVersion,
                                   underlines: underlines(inChapter: index, of: book))
        save(stored, chapter: index, of: book)
        logger.info("Chapter \(index) saved: \(stored.underlines.count) underlines, the model failed on \(failedCount) of \(phraseCount) phrases")
        // Its own task, so starting another chapter doesn't cancel the upload.
        await Task { await self.upload(stored, chapter: index, of: book) }.value
    }
}

private extension SavedUnderline {
    init(_ underline: Underline) {
        let reference = underline.reference
        self.init(id: underline.id, sentence: underline.sentence, paragraph: underline.paragraph, range: underline.range,
                  text: underline.text, kind: underline.kind.rawValue, decidedBy: underline.decidedBy.rawValue,
                  reference: ContextPassage(sentence: reference.sentence, paragraph: reference.paragraph, range: reference.range,
                                            text: reference.text))
    }
}
