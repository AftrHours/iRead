import Foundation
import OSLog
import UnderlineEngine

enum UnderlineRepoKnobs {
    static let engineVersion = 4
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
    #endif

    init(folder: URL = .applicationSupportDirectory.appending(path: "Underlines"),
         modelCheckSvc: ModelCheckSvc? = nil, cloudSvc: (any CloudSvc)? = nil) {
        self.folder = folder
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
    #endif

    private func run(_ index: Int, of content: BookContent, startingAt sentence: Int,
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
        let underlineCtrl = await engine()
        let indexed = await underlineCtrl.prepare(ChapterInputMapper.input(chapter: index, in: content))
        #if DEBUG
        foundRecords[book, default: [:]][index] = []
        #endif
        var hadModelFailure = false
        for await result in underlineCtrl.paragraphResults(in: indexed, startingAt: sentence) {
            hadModelFailure = hadModelFailure || result.records.contains { $0.dropped == .modelFailed }
            // A chapter stopped and started again finds some underlines twice.
            let known = Set(underlines(inChapter: index, of: book).map(\.id))
            foundUnderlines[book, default: [:]][index, default: []] += result.underlines.filter { !known.contains($0.id) }.map(SavedUnderline.init)
            #if DEBUG
            foundRecords[book, default: [:]][index, default: []] += result.records
            #endif
            if !result.underlines.isEmpty { continuation.yield() }
        }
        // A model failure means missed underlines, so the chapter is tried again next time.
        guard !Task.isCancelled, !hadModelFailure else { return }
        finishedChapters[book, default: []].insert(index)
        let stored = StoredChapter(parserVersion: parserVersion, engineVersion: UnderlineRepoKnobs.engineVersion,
                                   underlines: underlines(inChapter: index, of: book))
        save(stored, chapter: index, of: book)
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

    private func isFinished(_ chapter: Int, of book: String, parserVersion: Int) -> Bool {
        if finishedChapters[book]?.contains(chapter) == true { return true }
        guard let data = try? Data(contentsOf: fileURL(chapter: chapter, of: book)),
              let stored = try? JSONDecoder().decode(StoredChapter.self, from: data),
              isCurrent(stored, parserVersion: parserVersion) else { return false }
        use(stored, chapter: chapter, of: book)
        noteCloud("Saved on this device, so iCloud wasn't asked", chapter: chapter, of: book)
        return true
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

    private func fileURL(chapter: Int, of book: String) -> URL {
        folder.appending(path: "\(book)/chapter-\(chapter).json")
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
