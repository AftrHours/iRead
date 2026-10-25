import Foundation

struct TieBreakSvc: Sendable {
    func settle(
        _ rulesAnalysis: ResolvedAnalysis,
        sentences: [NumberedSentence],
        llm: LLMSvc,
        onProgress: @Sendable (EngineProgress) -> Void = { _ in }
    ) async -> ResolvedAnalysis {
        var analysis = rulesAnalysis
        if llm.isAvailable {
            let textByIndex = Dictionary(uniqueKeysWithValues: sentences.map { ($0.index, $0.text) })
            let names = firstNames(of: analysis)
            let undecidedCount = analysis.mentions.filter(\.isUndecided).count
            let chunkCount = names.count >= 2 ? (names.count + llm.namesPerCall - 1) / llm.namesPerCall : 0
            let total = chunkCount + min(undecidedCount, max(0, llm.maxCalls - 1))
            var done = 0
            onProgress(EngineProgress(done: 0, total: total))
            func step() {
                done += 1
                onProgress(EngineProgress(done: done, total: total))
            }
            await groupNames(in: &analysis, names: names, texts: textByIndex, llm: llm, onChunk: step)
            for index in analysis.mentions.indices where analysis.mentions[index].isUndecided {
                await settleDescription(at: index, in: &analysis, texts: textByIndex, llm: llm, onCall: step)
            }
            onProgress(EngineProgress(done: total, total: total))
        }
        MentionLinker.dropSmallDescribedEntities(in: &analysis)
        return analysis
    }

    private func firstNames(of analysis: ResolvedAnalysis) -> [EntityName] {
        analysis.entities.compactMap { $0.names.min { $0.sinceSentence < $1.sinceSentence } }
    }

    private func groupNames(in analysis: inout ResolvedAnalysis, names firstNames: [EntityName], texts: [Int: String],
                            llm: LLMSvc, onChunk: () -> Void) async {
        guard llm.allowsCall(callsSoFar: analysis.modelCalls), firstNames.count >= 2 else { return }
        let request = NameGroupRequest(
            names: firstNames.map(\.text),
            sentences: Set(firstNames.map(\.sinceSentence)).sorted().compactMap { i in texts[i].map { ModelSentence(index: i, text: $0) } }
        )
        var groups: [NameGroupChoice] = []
        for start in stride(from: 0, to: request.names.count, by: llm.namesPerCall) {
            let chunk = NameGroupRequest(
                names: Array(request.names[start..<min(start + llm.namesPerCall, request.names.count)]),
                sentences: request.sentences
            )
            groups += await llm.groupNames(chunk)
            onChunk()
        }
        analysis.modelCalls += 1

        let sinceByKey = Dictionary(firstNames.map { ($0.key, $0.sinceSentence) }, uniquingKeysWith: min)
        for group in groups where EvidenceGuard.accepts(group, for: request) {
            let keys = EvidenceGuard.supportedNames(group, for: request).map(NameKey.of)
            for (a, b) in zip(keys, keys.dropFirst()) {
                guard let from = analysis.entityKey(forName: b), let into = analysis.entityKey(forName: a) else { continue }
                let at = max(group.evidenceSentence, sinceByKey[a] ?? 0, sinceByKey[b] ?? 0)
                analysis.merge(from, into: into, at: at, decidedBy: .model)
            }
        }
    }

    private func settleDescription(at index: Int, in analysis: inout ResolvedAnalysis, texts: [Int: String],
                                   llm: LLMSvc, onCall: () -> Void) async {
        let mention = analysis.mentions[index]
        guard let own = mention.entity, llm.allowsCall(callsSoFar: analysis.modelCalls) else { return }
        let window = (mention.sentence - llm.contextSentenceCount)...mention.sentence
        let sentences = window.compactMap { i in texts[i].map { ModelSentence(index: i, text: $0) } }
        let candidates = candidateCharacters(for: mention, excluding: own, window: window, in: analysis, limit: llm.maxCandidates)
        guard !candidates.isEmpty else { return }

        let request = LinkRequest(mention: mention, sentences: sentences, candidates: candidates)
        let choice = await llm.chooseReference(request)
        analysis.modelCalls += 1
        onCall()
        guard let choice, EvidenceGuard.accepts(choice, for: request) else { return }

        let chosen = candidates[choice.candidateIndex].entity
        analysis.merge(own, into: chosen, at: analysis.entity(own)?.introSentence ?? mention.sentence, decidedBy: .model)
        analysis.mentions[index].decidedBy = .model
        analysis.mentions[index].isUndecided = false
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
