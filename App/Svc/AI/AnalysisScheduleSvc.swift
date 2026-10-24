import Foundation

struct AnalysisScheduleSvc: Sendable {
    func analysis(for content: BookContent) -> BookAnalysis {
        let entityResolveSvc = EntityResolveSvc()
        let sentences = SentenceText.numbered(in: content)
        let tags = entityResolveSvc.tagWords(in: sentences)
        let resolved = entityResolveSvc.resolveByRules(sentences: sentences, tags: tags).analysis
        return AnalysisMapper.map(resolved, content: content)
    }
}
