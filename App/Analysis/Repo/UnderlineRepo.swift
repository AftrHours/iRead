import Foundation
import OSLog
import UnderlineEngine

enum UnderlineRepoKnobs {
    static let engineVersion = 4
    /// "Underline whole book" saves a chapter when at most this share of its phrases failed in the model (it refuses some
    /// ordinary words, like "hate"), and leaves it out when more did, so a model that isn't answering saves nothing.
    static let bookMaxFailureShare = 0.1
}

actor UnderlineRepo {
    private struct StoredChapter: Codable {
        let parserVersion: Int
        /// nil in files saved before this field existed.
        let engineVersion: Int?
        let underlines: [SavedUnderline]
    }

    private static let recordType = "ChapterUnderlines"
    private let folder: URL
    /// Chapters worked out ahead and bundled with the app, laid out like `folder`. nil: none, as in tests.
    private let seedFolder: URL?
    private let logger = Logger(subsystem: Logger.appSubsystem, category: "storage")
    /// nil: rules only, as in tests.
    private let modelCheckSvc: ModelCheckSvc?
    /// nil: no iCloud, as in tests.
    private let cloudSvc: (any CloudSvc)?
    private var underlineCtrl: UnderlineCtrl?
    private var foundUnderlines: [String: [Int: [SavedUnderline]]] = [:]
    private var finishedChapters: [String: Set<Int>] = [:]
    private var running: Task<Void, Never>?
    #if DEBUG
    private var foundRecords: [String: [Int: [UnderlineRecord]]] = [:]
    private var cloudResults: [String: [Int: String]] = [:]
    private var bookRuns: [String: BookRun] = [:]
    private var bookTask: Task<Void, Never>?
    #endif

    init(folder: URL = .applicationSupportDirectory.appending(path: "Underlines"), seedFolder: URL? = nil,
         modelCheckSvc: ModelCheckSvc? = nil, cloudSvc: (any CloudSvc)? = nil) {
        self.folder = folder
        self.seedFolder = seedFolder
        self.modelCheckSvc = modelCheckSvc
        self.cloudSvc = cloudSvc
    }

    var cloudAccount: CloudAccount? {
        get async { await cloudSvc?.account() }
    }

    var usesModel: Bool {
        get async { await engine().usesModel }
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

    #if DEBUG
    func records(inChapter chapter: Int, of book: String) -> [UnderlineRecord] {
        foundRecords[book]?[chapter] ?? []
    }

    func cloudResult(inChapter chapter: Int, of book: String) -> String? {
        cloudResults[book]?[chapter]
    }

    /// Progress of "Underline whole book", for the debug sheet.
    struct BookRun: Sendable, Equatable {
        let total: Int
        var finished = 0
        var current: Int?
        /// Phrases the model failed on, in chapters that were saved anyway.
        var skippedPhrases = 0
        /// Chapters with too many failures, left for the next run.
        var leftOut: [Int] = []
        var isRunning = true
    }

    func bookRun(of book: String) -> BookRun? {
        bookRuns[book]
    }

    /// Where a book's chapters are saved. The folder appears once the first chapter is done.
    func savedFolder(of book: String) -> String {
        folder.appending(path: book).path(percentEncoded: false)
    }

    /// Underlines every chapter in order and saves each one, so a whole book can be worked out in one go. Chapters already
    /// saved are skipped, so a stopped run carries on where it was. The chapter being read is not touched.
    func startBook(_ content: BookContent) {
        guard bookTask == nil else { return }
        bookRuns[content.fingerprint] = BookRun(total: content.chapters.count)
        logger.info("Whole book: chapters are saved in \(self.savedFolder(of: content.fingerprint), privacy: .public)")
        bookTask = Task { await self.runBook(content) }
    }

    func stopBook() {
        bookTask?.cancel()
    }

    /// What "Export saved chapters" copied: chapter files per book fingerprint, and files left behind because an older
    /// engine made them.
    struct Export: Sendable {
        var chapters: [String: Int] = [:]
        var outdated = 0
    }

    /// Copies the saved chapters of every book into `destination`, one folder per book named by its fingerprint, the way
    /// the seeds bundled with the app are laid out. A file already there is replaced; nothing else in `destination` is
    /// touched. Chapters from an older engine are left out.
    func exportSaved(to destination: URL) throws -> Export {
        let manager = FileManager.default
        var export = Export()
        let books = try manager.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.isDirectoryKey])
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
        for book in books {
            let files = try manager.contentsOfDirectory(at: book, includingPropertiesForKeys: nil)
                .filter { $0.lastPathComponent.hasPrefix("chapter-") && $0.pathExtension == "json" }
            let current = files.filter { file in
                let stored = (try? Data(contentsOf: file)).flatMap { try? JSONDecoder().decode(StoredChapter.self, from: $0) }
                return stored?.engineVersion == UnderlineRepoKnobs.engineVersion
            }
            export.outdated += files.count - current.count
            guard !current.isEmpty else { continue }
            let target = destination.appending(path: book.lastPathComponent)
            try manager.createDirectory(at: target, withIntermediateDirectories: true)
            for file in current {
                let copy = target.appending(path: file.lastPathComponent)
                if manager.fileExists(atPath: copy.path(percentEncoded: false)) { try manager.removeItem(at: copy) }
                try manager.copyItem(at: file, to: copy)
            }
            export.chapters[book.lastPathComponent] = current.count
        }
        logger.info("Exported \(export.chapters.values.reduce(0, +)) chapters of \(export.chapters.count) books to \(destination.path(percentEncoded: false), privacy: .public)")
        return export
    }

    private func runBook(_ content: BookContent) async {
        let book = content.fingerprint
        defer {
            let left = (bookRuns[book]?.leftOut ?? []).map(String.init).joined(separator: ", ")
            logger.info("Whole book ended: \(self.bookRuns[book]?.finished ?? 0) of \(content.chapters.count) chapters done, left out: \(left.isEmpty ? "none" : left)")
            bookRuns[book]?.isRunning = false
            bookRuns[book]?.current = nil
            bookTask = nil
        }
        for chapter in content.chapters.indices {
            if Task.isCancelled { return }
            if !isFinished(chapter, of: book, parserVersion: content.parserVersion) {
                let paragraphs = content.chapters[chapter].paragraphs
                // A chapter without sentences has nothing to underline.
                if let first = content.sentences.firstIndex(where: { paragraphs.contains($0.paragraph) }) {
                    bookRuns[book]?.current = chapter
                    logger.info("Whole book: starting chapter \(chapter) of \(content.chapters.count)")
                    let (_, continuation) = AsyncStream<Void>.makeStream()
                    await run(chapter, of: content, startingAt: first, continuation: continuation, toleratesFailures: true)
                    if Task.isCancelled { return }
                    guard finishedChapters[book]?.contains(chapter) == true else {
                        bookRuns[book]?.leftOut.append(chapter)
                        continue
                    }
                }
            }
            bookRuns[book]?.finished += 1
        }
    }
    #endif

    private func run(_ index: Int, of content: BookContent, startingAt sentence: Int,
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
        let indexed = await underlineCtrl.prepare(ChapterInputMapper.input(chapter: index, in: content))
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

    /// The system can report the model available while every call fails, and the engine then drops every phrase,
    /// so the model is tried once first and the engine falls back to rules.
    private func engine() async -> UnderlineCtrl {
        if let underlineCtrl { return underlineCtrl }
        let canUseModel = await modelCheckSvc?.modelAnswers() ?? false
        if let underlineCtrl { return underlineCtrl }
        let made = UnderlineCtrl(model: canUseModel ? .automatic : .rulesOnly)
        underlineCtrl = made
        return made
    }

    /// A chapter is finished when this device saved it, or when the app comes with it: the bundled books are worked out
    /// ahead, so a reader never waits on the engine for them. Either way iCloud isn't asked.
    private func isFinished(_ chapter: Int, of book: String, parserVersion: Int) -> Bool {
        if finishedChapters[book]?.contains(chapter) == true { return true }
        if let stored = storedChapter(at: fileURL(chapter: chapter, of: book, in: folder), parserVersion: parserVersion) {
            use(stored, chapter: chapter, of: book)
            noteCloud("Saved on this device, so iCloud wasn't asked", chapter: chapter, of: book)
            return true
        }
        if let seedFolder,
           let stored = storedChapter(at: fileURL(chapter: chapter, of: book, in: seedFolder), parserVersion: parserVersion) {
            use(stored, chapter: chapter, of: book)
            noteCloud("Comes with the app, so iCloud wasn't asked", chapter: chapter, of: book)
            return true
        }
        return false
    }

    /// nil when there's no file, or it was made by another parser or engine version.
    private func storedChapter(at url: URL, parserVersion: Int) -> StoredChapter? {
        guard let data = try? Data(contentsOf: url),
              let stored = try? JSONDecoder().decode(StoredChapter.self, from: data),
              isCurrent(stored, parserVersion: parserVersion) else { return nil }
        return stored
    }

    private func isCurrent(_ stored: StoredChapter, parserVersion: Int) -> Bool {
        stored.parserVersion == parserVersion && stored.engineVersion == UnderlineRepoKnobs.engineVersion
    }

    private func use(_ stored: StoredChapter, chapter: Int, of book: String) {
        foundUnderlines[book, default: [:]][chapter] = stored.underlines
        finishedChapters[book, default: []].insert(chapter)
    }

    private func save(_ stored: StoredChapter, chapter: Int, of book: String) {
        let url = fileURL(chapter: chapter, of: book)
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(stored).write(to: url, options: .atomic)
        } catch {
            logger.error("Couldn't save underlines for \(book, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    private func fileURL(chapter: Int, of book: String, in folder: URL? = nil) -> URL {
        (folder ?? self.folder).appending(path: "\(book)/chapter-\(chapter).json")
    }

    /// nil when iCloud has no current copy or can't be reached.
    private func cloudChapter(_ chapter: Int, of book: String, parserVersion: Int) async -> StoredChapter? {
        guard let cloudSvc else { return nil }
        do {
            guard case .bytes(let data)? = try await cloudSvc.record(named: recordName(chapter, of: book), in: .reader)?["chapter"] else {
                noteCloud("Not in iCloud yet, so the engine ran", chapter: chapter, of: book)
                return nil
            }
            let stored = try JSONDecoder().decode(StoredChapter.self, from: data)
            guard isCurrent(stored, parserVersion: parserVersion) else {
                noteCloud("In iCloud from an older engine, so the engine ran", chapter: chapter, of: book)
                return nil
            }
            noteCloud("Loaded from iCloud", chapter: chapter, of: book)
            return stored
        } catch {
            logger.info("No underlines from iCloud for \(book, privacy: .public): \(error.localizedDescription, privacy: .public)")
            noteCloud("Couldn't ask iCloud: \(error.localizedDescription)", chapter: chapter, of: book)
            return nil
        }
    }

    private func upload(_ stored: StoredChapter, chapter: Int, of book: String) async {
        guard let cloudSvc else { return }
        do {
            try await cloudSvc.save(["chapter": .bytes(JSONEncoder().encode(stored))], asRecord: recordName(chapter, of: book),
                                    ofType: Self.recordType, in: .reader)
            noteCloud("Underlined here and saved to iCloud", chapter: chapter, of: book)
        } catch {
            logger.info("Couldn't put underlines in iCloud for \(book, privacy: .public): \(error.localizedDescription, privacy: .public)")
            noteCloud("Underlined here, but couldn't save to iCloud: \(error.localizedDescription)", chapter: chapter, of: book)
        }
    }

    /// For the debug sheet only.
    private func noteCloud(_ result: String, chapter: Int, of book: String) {
        #if DEBUG
        cloudResults[book, default: [:]][chapter] = result
        #endif
    }

    private func recordName(_ chapter: Int, of book: String) -> String {
        "\(book)-\(chapter)"
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
