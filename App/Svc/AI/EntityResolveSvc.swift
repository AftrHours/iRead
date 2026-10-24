//
//  EntityResolveSvc.swift
//  iRead
//
//  Created by abr on 24/10/26.
//

import Foundation

struct EntityResolveSvc {
    struct RulesResult: Sendable {
        var analysis: ResolvedAnalysis
        var undecided: [Int]
    }

    func tagWords(in sentences: [NumberedSentence]) -> SentenceTags {
        let engine = detectTaggingEngine()
        return SentenceTags(engine: engine, tokens: tagWords(in: sentences.map(\.text), engine: engine))
    }

    func resolveByRules(sentences: [NumberedSentence], tags: SentenceTags) -> RulesResult {
        let mentions = findMentions(in: sentences, tags: tags)
        let cast = buildCast(from: mentions, sentences: sentences, tags: tags)
        return linkMentions(mentions, sentences: sentences, cast: cast)
    }

    static func nameKey(_ text: String) -> String {
        text.lowercased().replacingOccurrences(of: ".", with: "").split(separator: " ").joined(separator: " ")
    }

    static var knobSummary: String {
        [mentionKnobSummary, castKnobSummary, linkKnobSummary].joined(separator: " · ")
    }
}
