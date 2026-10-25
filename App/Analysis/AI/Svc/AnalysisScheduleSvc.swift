import Foundation

struct AnalysisScheduleSvc: Sendable {
    private let wordTagSvc = WordTagSvc()
    private let tieBreakSvc = TieBreakSvc()
    private let modelAvailSvc = ModelAvailSvc()

    func rulesPass(for content: BookContent) -> RulesPass {
        let clock = ContinuousClock()
        let started = clock.now
        let sentences = StoryStart.storySentences(SentenceText.numbered(in: content), in: content)
        let tags = wordTagSvc.tag(sentences)
        let mentions = MentionFinder.mentions(in: sentences, tags: tags)
        let cast = CastBuilder.cast(from: mentions, sentences: sentences)
        let analysis = MentionLinker.link(mentions, to: cast, sentences: sentences)
        let duration = started.duration(to: clock.now)
        #if DEBUG
        print("[Engine] Phase 1 done in \(duration.formatted(.units(allowed: [.seconds], fractionalPart: .show(length: 1)))): "
            + "\(sentences.count) sentences, \(analysis.mentions.count) mentions, \(analysis.entities.count) characters")
        #endif
        return RulesPass(
            content: content,
            sentences: sentences,
            analysis: analysis,
            usesNaturalLanguage: wordTagSvc.hasEnglishModels(),
            duration: duration
        )
    }

    func analysis(from pass: RulesPass) -> AnalysisSnapshot {
        AnalysisSnapshot(
            pass: pass,
            resolved: pass.analysis,
            book: AnalysisMapper.map(pass.analysis, content: pass.content),
            isModelAvailable: modelAvailSvc.isFoundationModelsAvailable,
            modelDuration: nil
        )
    }

    func refinedAnalysis(from pass: RulesPass, onProgress: @Sendable (EngineProgress) -> Void = { _ in }) async -> AnalysisSnapshot {
        let clock = ContinuousClock()
        let started = clock.now
        let llm = modelAvailSvc.makeLLMSvc()
        let resolved = await tieBreakSvc.settle(pass.analysis, sentences: pass.sentences, llm: llm, onProgress: onProgress)
        #if DEBUG
        print("[Engine] Phase 2 done in \(started.duration(to: clock.now).formatted(.units(allowed: [.seconds], fractionalPart: .show(length: 1)))): "
            + "\(resolved.modelCalls) model calls, \(resolved.mentions.filter { $0.decidedBy == .model }.count) descriptions settled, "
            + "model \(llm.isAvailable ? "on" : "off")")
        #endif
        return AnalysisSnapshot(
            pass: pass,
            resolved: resolved,
            book: AnalysisMapper.map(resolved, content: pass.content),
            isModelAvailable: llm.isAvailable,
            modelDuration: started.duration(to: clock.now)
        )
    }
}
