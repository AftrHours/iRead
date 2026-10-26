import Foundation

enum AnalysisRepoKnobs {
    static let throttlePause: Duration = .seconds(30)
}

actor AnalysisRepo {
    private let content: @Sendable (UUID) async throws -> BookContent
    private let prepassSvc: BookPrepassSvc
    private let chapterSvc: ChapterAnalysisSvc
    private let store: ChapterAnalysisStore
    private let makeLLM: @Sendable () -> any LLMSvc
    private var running: (bookID: UUID, token: UUID, task: Task<Void, Never>)?
    private var snapshots: [UUID: AnalysisSnapshot] = [:]
    private var listeners: [UUID: [UUID: AsyncStream<Int>.Continuation]] = [:]

    init(content: @escaping @Sendable (UUID) async throws -> BookContent, prepassSvc: BookPrepassSvc, chapterSvc: ChapterAnalysisSvc,
         store: ChapterAnalysisStore, makeLLM: @escaping @Sendable () -> any LLMSvc) {
        self.content = content
        self.prepassSvc = prepassSvc
        self.chapterSvc = chapterSvc
        self.store = store
        self.makeLLM = makeLLM
    }

    func startAnalysis(for bookID: UUID) {
        guard running?.bookID != bookID else { return }
        stopAnalysis()
        let token = UUID()
        running = (bookID, token, Task.detached(priority: .utility) { await self.run(bookID, token: token) })
    }

    func stopAnalysis() {
        running?.task.cancel()
        if let bookID = running?.bookID { finish(bookID) }
        running = nil
    }

    func analysis(for bookID: UUID) -> BookAnalysis {
        snapshots[bookID]?.book ?? BookAnalysis(entities: [], mentions: [])
    }

    func snapshot(for bookID: UUID) -> AnalysisSnapshot? {
        snapshots[bookID]
    }

    func progress(for bookID: UUID) -> EngineProgress? {
        snapshots[bookID].map { EngineProgress(done: $0.chaptersDone, total: $0.chaptersTotal) }
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
        guard let content = try? await content(bookID) else { return await finishIfCurrent(bookID, token: token) }
        let book = prepassSvc.prepare(content)
        let llm = makeLLM()
        if llm.isAvailable { llm.prewarm() }
        let version = ChapterAnalysisKnobs.engineVersion
        var memory = CastMemory.empty
        var mentions: [ResolvedMention] = []
        var calls = 0
        var failed = 0
        var isResuming = true
        var hasUnpublished = false
        for (done, chapter) in book.chapters.enumerated() {
            if Task.isCancelled { return }
            let result: ChapterAnalysis
            if isResuming, let stored = store.load(bookID: bookID, chapter: chapter, engineVersion: version, parserVersion: content.parserVersion) {
                result = stored
            } else {
                isResuming = false
                if hasUnpublished {
                    await publish(snapshot(book, memory, mentions, done, calls, failed, llm), chapter: chapter - 1, for: bookID)
                }
                await waitWhileHot()
                if Task.isCancelled { return }
                result = await chapterSvc.analyze(chapter: chapter, book: book, memory: memory, mentionsSoFar: mentions, llm: llm)
                if Task.isCancelled { return }
                try? store.save(result, bookID: bookID)
            }
            memory = result.memory
            mentions += result.mentions
            calls += result.modelCalls
            failed += result.failedSlices
            hasUnpublished = isResuming
            if !isResuming {
                await publish(snapshot(book, memory, mentions, done + 1, calls, failed, llm), chapter: chapter, for: bookID)
            }
        }
        if hasUnpublished {
            await publish(snapshot(book, memory, mentions, book.chapters.count, calls, failed, llm), chapter: book.chapters.upperBound - 1, for: bookID)
        }
        await finishIfCurrent(bookID, token: token)
    }

    private nonisolated func snapshot(_ book: PreparedBook, _ memory: CastMemory, _ mentions: [ResolvedMention],
                                      _ done: Int, _ calls: Int, _ failed: Int, _ llm: any LLMSvc) -> AnalysisSnapshot {
        AnalysisSnapshot(
            book: AnalysisMapper.map(memory: memory, mentions: mentions, content: book.content),
            resolved: ResolvedAnalysis(entities: memory.entities, mentions: mentions),
            content: book.content,
            chaptersDone: done,
            chaptersTotal: book.chapters.count,
            modelCalls: calls,
            failedSlices: failed,
            usesModel: llm.isAvailable
        )
    }

    private nonisolated func waitWhileHot() async {
        while !Task.isCancelled, ProcessInfo.processInfo.thermalState == .serious || ProcessInfo.processInfo.thermalState == .critical
                || ProcessInfo.processInfo.isLowPowerModeEnabled {
            try? await Task.sleep(for: AnalysisRepoKnobs.throttlePause)
        }
    }

    private func publish(_ snapshot: AnalysisSnapshot, chapter: Int, for bookID: UUID) {
        snapshots[bookID] = snapshot
        listeners[bookID]?.values.forEach { $0.yield(chapter) }
    }

    private func finish(_ bookID: UUID) {
        listeners[bookID]?.values.forEach { $0.finish() }
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
