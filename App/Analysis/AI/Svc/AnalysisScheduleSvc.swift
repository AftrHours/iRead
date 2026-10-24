import Foundation

struct AnalysisScheduleSvc: Sendable {
    private let wordTagSvc = WordTagSvc()
    private let tieBreakSvc = TieBreakSvc()
    private let modelAvailSvc = ModelAvailSvc()

    func rulesPass(for content: BookContent) -> RulesPass {
        let sentences = SentenceText.numbered(in: content)
        let tags = wordTagSvc.tag(sentences)
        let mentions = MentionFinder.mentions(in: sentences, tags: tags)
        let cast = CastBuilder.cast(from: mentions, sentences: sentences)
        let analysis = MentionLinker.link(mentions, to: cast, sentences: sentences)
        return RulesPass(content: content, sentences: sentences, analysis: analysis)
    }

    func analysis(from pass: RulesPass) -> BookAnalysis {
        AnalysisMapper.map(pass.analysis, content: pass.content)
    }

    func refinedAnalysis(from pass: RulesPass) async -> BookAnalysis {
        let resolved = await tieBreakSvc.settle(pass.analysis, sentences: pass.sentences, llm: modelAvailSvc.makeLLMSvc())
        return AnalysisMapper.map(resolved, content: pass.content)
    }
}
