import Foundation
import OSLog
import UnderlineEngine

enum UnderlineRepoKnobs {
    /// Bump when the engine's results change, so saved chapters are worked out again.
    static let engineVersion = 2
    static let throttlePause: Duration = .seconds(30)
}

/// Works out a book's underlines in the background, one chapter at a time, and saves each finished chapter.
actor UnderlineRepo {
    private static let logger = Logger(subsystem: "com.AftrHours.iRead", category: "underlines")

    private let content: @Sendable (UUID) async throws -> BookContent
    private let store: ChapterUnderlineStore
    private let makeCtrl: @Sendable () -> UnderlineCtrl
    private let modelAnswers: @Sendable () async -> Bool
    private var running: (bookID: UUID, token: UUID, task: Task<Void, Never>)?
    private var focus: ReadingPosition?
    private var found: [UUID: [String: Underline]] = [:]
    private var dropped: [UUID: [Int: [DroppedPhrase]]] = [:]
    private var progress: [UUID: UnderlineProgress] = [:]
    private var listeners: [UUID: [UUID: AsyncStream<Int>.Continuation]] = [:]

    init(content: @escaping @Sendable (UUID) async throws -> BookContent, store: ChapterUnderlineStore, makeCtrl: @escaping @Sendable () -> UnderlineCtrl,
         modelAnswers: @escaping @Sendable () async -> Bool) {
        self.content = content
        self.store = store
        self.makeCtrl = makeCtrl
        self.modelAnswers = modelAnswers
    }

    func start(for bookID: UUID, at position: ReadingPosition) {
        focus = position
        guard running?.bookID != bookID else { return }
        stop()
        let token = UUID()
        running = (bookID, token, Task.detached(priority: .utility) { await self.run(bookID, token: token) })
    }

    func stop() {
        running?.task.cancel()
        if let bookID = running?.bookID {
            setPhase(.stopped, for: bookID)
            finish(bookID)
        }
        running = nil
    }

    /// The chapter holding `position` goes next, once the chapter being worked on is done.
    func setFocus(_ position: ReadingPosition) {
        focus = position
    }

    func underlines(for bookID: UUID) -> [Underline] {
        Array((found[bookID] ?? [:]).values)
    }

    func underline(id: String, for bookID: UUID) -> Underline? {
        found[bookID]?[id]
    }

    func droppedPhrases(for bookID: UUID) -> [Int: [DroppedPhrase]] {
        dropped[bookID] ?? [:]
    }

    func progress(for bookID: UUID) -> UnderlineProgress? {
        progress[bookID]
    }

    func updates(for bookID: UUID) -> AsyncStream<Int> {
        let (stream, continuation) = AsyncStream<Int>.makeStream()
        guard running?.bookID == bookID else {
            continuation.finish()
            return stream
        }
        let id = UUID()
        listeners[bookID, default: [:]][id] = continuation
        continuation.onTermination = { _ in Task { await self.removeListener(id, of: bookID) } }
        return stream
    }

    private nonisolated func run(_ bookID: UUID, token: UUID) async {
        guard let content = try? await content(bookID) else {
            await setPhase(.stopped, for: bookID)
            return await finishIfCurrent(bookID, token: token)
        }
        let ctrl = makeCtrl()
        await begin(bookID, usesModel: ctrl.usesModel, chapterCount: content.chapters.count)
        Self.logger.info("Underlines start, model: \(ctrl.usesModel), chapters: \(content.chapters.count)")
        var pending = Set(content.chapters.indices)
        for chapter in content.chapters.indices {
            if let stored = store.load(bookID: bookID, chapter: chapter, engineVersion: UnderlineRepoKnobs.engineVersion,
                                       parserVersion: content.parserVersion, usesModel: ctrl.usesModel) {
                pending.remove(chapter)
                await add(stored.underlines, for: bookID)
                await setDropped(stored.dropped, chapter: chapter, for: bookID)
                await markDone(chapter, for: bookID)
            }
        }
        var last = -1
        while let chapter = await nextChapter(in: pending, after: last, content: content) {
            await waitWhileHot(bookID)
            if Task.isCancelled { return }
            await setPhase(.working(chapter: chapter), for: bookID)
            let clock = ContinuousClock()
            let began = clock.now
            let indexed = await ctrl.prepare(ChapterInputMapper.input(chapter: chapter, in: content))
            var kept: [Underline] = []
            var droppedHere: [DroppedPhrase] = []
            await setDropped([], chapter: chapter, for: bookID)
            for await result in ctrl.paragraphResults(in: indexed, startingAt: await startSentence(of: chapter, content: content)) {
                kept += result.underlines
                droppedHere += result.records.compactMap(DroppedPhrase.init)
                await add(result.underlines, for: bookID)
                await setDropped(droppedHere, chapter: chapter, for: bookID)
            }
            // A cancelled stream ends early: never save a part of a chapter as if it were all of it.
            if Task.isCancelled { return }
            // Availability can say yes while every call fails, which looks like a chapter with nothing to underline.
            // Saving that would keep it empty for good, so stop here and try again the next time the book opens.
            if kept.isEmpty, ctrl.usesModel, await !modelAnswers() {
                Self.logger.error("The model isn't answering: stopped at chapter \(chapter), nothing saved")
                await setPhase(.modelNotAnswering, for: bookID)
                return await finishIfCurrent(bookID, token: token)
            }
            do {
                try store.save(StoredUnderlines(chapter: chapter, engineVersion: UnderlineRepoKnobs.engineVersion, parserVersion: content.parserVersion,
                                                usedModel: ctrl.usesModel, underlines: kept, dropped: droppedHere), bookID: bookID)
            } catch {
                Logger(subsystem: "com.AftrHours.iRead", category: "storage").error("Saving underlines failed: \(error.localizedDescription)")
            }
            Self.logger.info("Chapter \(chapter): \(kept.count) underlines in \(clock.now - began)")
            pending.remove(chapter)
            await markDone(chapter, for: bookID)
            last = chapter
        }
        await setPhase(.finished, for: bookID)
        await finishIfCurrent(bookID, token: token)
    }

    /// The focused chapter if it isn't done, otherwise the next one in reading order, then wrapping to the start.
    private func nextChapter(in pending: Set<Int>, after last: Int, content: BookContent) -> Int? {
        if let focus, content.paragraphs.indices.contains(focus.paragraph), pending.contains(content.paragraphs[focus.paragraph].chapterIndex) {
            return content.paragraphs[focus.paragraph].chapterIndex
        }
        return pending.filter { $0 > last }.min() ?? pending.min()
    }

    /// The reader's paragraph when they're in this chapter, otherwise the chapter's start.
    private func startSentence(of chapter: Int, content: BookContent) -> Int {
        let chapterParagraphs = content.chapters[chapter].paragraphs
        let paragraph = focus.map(\.paragraph).flatMap { chapterParagraphs.contains($0) ? $0 : nil } ?? chapterParagraphs.lowerBound
        return content.sentences.firstIndex { $0.paragraph >= paragraph } ?? 0
    }

    private nonisolated func waitWhileHot(_ bookID: UUID) async {
        while !Task.isCancelled, ProcessInfo.processInfo.thermalState == .serious || ProcessInfo.processInfo.thermalState == .critical
                || ProcessInfo.processInfo.isLowPowerModeEnabled {
            await setPhase(.paused, for: bookID)
            try? await Task.sleep(for: UnderlineRepoKnobs.throttlePause)
        }
    }

    private func begin(_ bookID: UUID, usesModel: Bool, chapterCount: Int) {
        progress[bookID] = UnderlineProgress(usesModel: usesModel, chapterCount: chapterCount)
    }

    private func setPhase(_ phase: UnderlineProgress.Phase, for bookID: UUID) {
        progress[bookID, default: UnderlineProgress()].phase = phase
        if case .working = phase { progress[bookID]?.workingSince = .now }
    }

    private func setDropped(_ phrases: [DroppedPhrase], chapter: Int, for bookID: UUID) {
        dropped[bookID, default: [:]][chapter] = phrases
    }

    private func markDone(_ chapter: Int, for bookID: UUID) {
        progress[bookID]?.doneChapters.insert(chapter)
    }

    private func add(_ underlines: [Underline], for bookID: UUID) {
        guard !underlines.isEmpty else { return }
        for underline in underlines { found[bookID, default: [:]][underline.id] = underline }
        for continuation in (listeners[bookID] ?? [:]).values { continuation.yield(found[bookID]?.count ?? 0) }
    }

    private func finish(_ bookID: UUID) {
        for continuation in (listeners[bookID] ?? [:]).values { continuation.finish() }
        listeners[bookID] = nil
    }

    private func finishIfCurrent(_ bookID: UUID, token: UUID) {
        guard running?.token == token else { return }
        finish(bookID)
        running = nil
    }

    private func removeListener(_ id: UUID, of bookID: UUID) {
        listeners[bookID]?[id] = nil
    }
}
