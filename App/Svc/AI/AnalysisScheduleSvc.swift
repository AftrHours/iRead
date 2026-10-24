import Foundation

struct AnalysisScheduleSvc: Sendable {
    func rulesPass(for content: BookContent) -> RulesPass {
        let entityResolveSvc = EntityResolveSvc()
        let sentences = SentenceText.numbered(in: content)
        let tags = entityResolveSvc.tagWords(in: sentences)
        return RulesPass(content: content, sentences: sentences, rules: entityResolveSvc.resolveByRules(sentences: sentences, tags: tags))
    }

    func analysis(from pass: RulesPass) -> BookAnalysis {
        AnalysisMapper.map(pass.rules.analysis, content: pass.content)
    }

    func refinedAnalysis(from pass: RulesPass) async -> BookAnalysis {
        let resolved = await EntityResolveSvc().breakTies(pass.rules, sentences: pass.sentences, llm: ModelAvailSvc().makeLLMSvc())
        return AnalysisMapper.map(resolved, content: pass.content)
    }
}
