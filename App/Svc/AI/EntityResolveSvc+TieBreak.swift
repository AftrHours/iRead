import Foundation

extension EntityResolveSvc {
    func breakTies(_ rules: RulesResult, sentences: [NumberedSentence], llm: LLMSvc) async -> ResolvedAnalysis {
        var analysis = rules.analysis
        if llm.isAvailable {
            let textByIndex = Dictionary(uniqueKeysWithValues: sentences.map { ($0.index, $0.text) })
            await groupNames(in: &analysis, texts: textByIndex, llm: llm)
            for index in rules.undecided {
                await settleDescription(at: index, in: &analysis, texts: textByIndex, llm: llm)
            }
        }
        dropSmallDescribedEntities(in: &analysis)
        return analysis
    }

    private func groupNames(in analysis: inout ResolvedAnalysis, texts: [Int: String], llm: LLMSvc) async {
        guard llm.allowsCall(callsSoFar: analysis.modelCalls) else { return }
        let firstNames = analysis.entities.compactMap { $0.names.min { $0.sinceSentence < $1.sinceSentence } }
        guard firstNames.count >= 2 else { return }
        let request = NameGroupRequest(
            names: firstNames.map(\.text),
            sentences: Set(firstNames.map(\.sinceSentence)).sorted().compactMap { i in texts[i].map { ModelSentence(index: i, text: $0) } }
        )
        let result = await llm.groupNames(request)
        analysis.modelCalls += 1
        analysis.modelFailures += result.failedCalls

        let sinceByKey = Dictionary(firstNames.map { ($0.key, $0.sinceSentence) }, uniquingKeysWith: min)
        for group in result.groups where EvidenceGuard.accepts(group, for: request) {
            let keys = EvidenceGuard.supportedNames(group, for: request).map(Self.nameKey)
            for (a, b) in zip(keys, keys.dropFirst()) {
                guard let from = analysis.entityKey(forName: b), let into = analysis.entityKey(forName: a) else { continue }
                let at = max(group.evidenceSentence, sinceByKey[a] ?? 0, sinceByKey[b] ?? 0)
                analysis.merge(from, into: into, at: at, decidedBy: .model)
            }
        }
    }

    private func settleDescription(at index: Int, in analysis: inout ResolvedAnalysis, texts: [Int: String], llm: LLMSvc) async {
        let mention = analysis.mentions[index]
        guard let own = mention.entity, llm.allowsCall(callsSoFar: analysis.modelCalls) else { return }
        let window = (mention.sentence - llm.contextSentenceCount)...mention.sentence
        let sentences = window.compactMap { i in texts[i].map { ModelSentence(index: i, text: $0) } }
        let candidates = candidateCharacters(for: mention, excluding: own, window: window, in: analysis, limit: llm.maxCandidates)
        guard !candidates.isEmpty else { return }

        let request = LinkRequest(mention: mention, sentences: sentences, candidates: candidates)
        let choice = await llm.chooseReference(request)
        analysis.modelCalls += 1
        guard let choice else { analysis.modelFailures += 1; return }
        guard EvidenceGuard.accepts(choice, for: request) else { return }

        let chosen = candidates[choice.candidateIndex].entity
        analysis.merge(own, into: chosen, at: analysis.entity(own)?.introSentence ?? mention.sentence, decidedBy: .model)
        analysis.mentions[index].decidedBy = .model
    }

    private func candidateCharacters(for mention: ResolvedMention, excluding own: Int, window: ClosedRange<Int>,
                                     in analysis: ResolvedAnalysis, limit: Int) -> [ModelCandidate] {
        let earlier = analysis.linkedMentions.filter { $0.sentence <= mention.sentence }.reversed()
        let ordered = earlier.filter { window.contains($0.sentence) } + earlier.filter { !window.contains($0.sentence) }
        var candidates: [ModelCandidate] = []
        for linked in ordered where candidates.count < limit {
            guard let key = analysis.entityKey(of: linked, asOf: mention.sentence), key != analysis.finalKey(of: own),
                  !candidates.contains(where: { $0.entity == key }) else { continue }

            let label = analysis.entity(key).flatMap { $0.isNamed ? $0.label : nil } ?? linked.text
            candidates.append(ModelCandidate(entity: key, label: label))
        }
        return candidates
    }
}
