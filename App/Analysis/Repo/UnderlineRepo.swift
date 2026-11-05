import Foundation
import OSLog
import UnderlineEngine

enum UnderlineRepoKnobs {
    /// Saved with each finished chapter. Bump it when you change UnderlineEngine's pinned revision in project.yml,
    /// so chapters underlined by the old engine are underlined again.
    static let engineVersion = 1
}

/// Runs UnderlineEngine on one chapter at a time and keeps what it finds: in memory while the app runs, and on disk
/// once a chapter is finished, so each chapter is underlined only once.
actor UnderlineRepo {
    private struct StoredChapter: Codable {
        let parserVersion: Int
        /// nil in files saved before this field existed.
        let engineVersion: Int?
        let underlines: [Underline]
    }

    private let booksFolder: URL
    private let logger = Logger(subsystem: Logger.appSubsystem, category: "storage")
    private let underlineCtrl = UnderlineCtrl()
    private var foundUnderlines: [UUID: [Int: [Underline]]] = [:]
    private var finishedChapters: [UUID: Set<Int>] = [:]
    private var running: Task<Void, Never>?
    #if DEBUG
    /// Every phrase the engine considered this session, kept or dropped, for the debug view.
    private var foundRecords: [UUID: [Int: [UnderlineRecord]]] = [:]
    #endif

    init(folder: URL = .applicationSupportDirectory.appending(path: "Books")) {
        booksFolder = folder
    }

    /// Whether pick and confirm use the on-device model, or only rules.
    var usesModel: Bool {
        underlineCtrl.usesModel
    }

    /// Underlines a chapter from `sentence` to its end, then from its start. Yields after each paragraph that adds
    /// underlines and finishes when the chapter is done or nobody listens anymore. Starting another chapter stops this one.
    func underline(_ chapter: ChapterInput, of bookID: UUID, parserVersion: Int, startingAt sentence: Int) -> AsyncStream<Void> {
        let (stream, continuation) = AsyncStream<Void>.makeStream()
        guard !isFinished(chapter.chapterIndex, of: bookID, parserVersion: parserVersion) else {
            continuation.yield()
            continuation.finish()
            return stream
        }
        running?.cancel()
        let task = Task {
            await self.run(chapter, of: bookID, parserVersion: parserVersion, startingAt: sentence, continuation: continuation)
        }
        running = task
        continuation.onTermination = { _ in task.cancel() }
        return stream
    }

    func underlines(inChapter chapter: Int, of bookID: UUID) -> [Underline] {
        foundUnderlines[bookID]?[chapter] ?? []
    }

    func underline(withID id: String, of bookID: UUID) -> Underline? {
        foundUnderlines[bookID]?.values.lazy.flatMap { $0 }.first { $0.id == id }
    }

    #if DEBUG
    func records(inChapter chapter: Int, of bookID: UUID) -> [UnderlineRecord] {
        foundRecords[bookID]?[chapter] ?? []
    }
    #endif

    private func run(_ chapter: ChapterInput, of bookID: UUID, parserVersion: Int, startingAt sentence: Int,
                     continuation: AsyncStream<Void>.Continuation) async {
        defer { continuation.finish() }
        let index = chapter.chapterIndex
        let indexed = await underlineCtrl.prepare(chapter)
        #if DEBUG
        foundRecords[bookID, default: [:]][index] = []
        #endif
        for await result in underlineCtrl.paragraphResults(in: indexed, startingAt: sentence) {
            // A chapter stopped earlier and started again finds some underlines twice.
            let known = Set(underlines(inChapter: index, of: bookID).map(\.id))
            foundUnderlines[bookID, default: [:]][index, default: []] += result.underlines.filter { !known.contains($0.id) }
            #if DEBUG
            foundRecords[bookID, default: [:]][index, default: []] += result.records
            #endif
            if !result.underlines.isEmpty { continuation.yield() }
        }
        guard !Task.isCancelled else { return }
        finishedChapters[bookID, default: []].insert(index)
        save(StoredChapter(parserVersion: parserVersion, engineVersion: UnderlineRepoKnobs.engineVersion,
                           underlines: underlines(inChapter: index, of: bookID)), chapter: index, of: bookID)
    }

    private func isFinished(_ chapter: Int, of bookID: UUID, parserVersion: Int) -> Bool {
        if finishedChapters[bookID]?.contains(chapter) == true { return true }
        guard let data = try? Data(contentsOf: fileURL(chapter: chapter, of: bookID)),
              let stored = try? JSONDecoder().decode(StoredChapter.self, from: data),
              stored.parserVersion == parserVersion, stored.engineVersion == UnderlineRepoKnobs.engineVersion else { return false }
        foundUnderlines[bookID, default: [:]][chapter] = stored.underlines
        finishedChapters[bookID, default: []].insert(chapter)
        return true
    }

    private func save(_ stored: StoredChapter, chapter: Int, of bookID: UUID) {
        let url = fileURL(chapter: chapter, of: bookID)
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(stored).write(to: url, options: .atomic)
        } catch {
            logger.error("Couldn't save underlines for \(bookID.uuidString, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    private func fileURL(chapter: Int, of bookID: UUID) -> URL {
        booksFolder.appending(path: "\(bookID.uuidString)/underlines/chapter-\(chapter).json")
    }
}
