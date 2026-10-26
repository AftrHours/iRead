import Foundation

enum ChapterAnalysisKnobs {
    static let engineVersion = 1
    static let budgetShare = 0.35
}

struct ChapterAnalysisSvc: Sendable {
    func analyze(chapter: Int, book: PreparedBook, memory: CastMemory, mentionsSoFar: [ResolvedMention], llm: LLMSvc) async -> ChapterAnalysis {
        let content = book.content
        let pairs = zip(book.sentences, book.tags.tokens).filter { content.paragraphs[content.sentences[$0.0.index].paragraph].chapterIndex == chapter }
        let sentences = pairs.map(\.0)
        let mentions = MentionFinder.mentions(in: sentences, tags: SentenceTags(tokens: pairs.map(\.1)), names: book.vocabulary.names)
        let cast = CastBuilder.extend(memory, with: mentions, sentences: sentences, vocabulary: book.vocabulary)
        var linked = MentionLinker.link(mentions, memory: cast, earlier: mentionsSoFar, sentences: sentences)
        var reader = SliceReader(llm: llm, earlier: mentionsSoFar, vocabulary: book.vocabulary,
                                 sentenceText: Dictionary(uniqueKeysWithValues: sentences.map { ($0.index, $0.text) }))
        if llm.isAvailable {
            let maxCharacters = Int(Double(llm.contextSize) * ChapterAnalysisKnobs.budgetShare) * ChapterSlicerKnobs.charactersPerToken
            for slice in ChapterSlicer.slices(sentences, maxCharacters: maxCharacters) where !Task.isCancelled {
                await reader.read(slice, into: &linked, canSplit: true)
            }
        }
        SymbolAssigner.assign(&linked.memory, mentionsSoFar: mentionsSoFar + linked.mentions, vocabulary: book.vocabulary, chapter: chapter)
        return ChapterAnalysis(chapter: chapter, engineVersion: ChapterAnalysisKnobs.engineVersion,
                               parserVersion: content.parserVersion, mentions: linked.mentions,
                               memory: linked.memory, modelCalls: reader.calls, failedSlices: reader.failed)
    }
}

private struct SliceReader {
    let llm: LLMSvc
    let earlier: [ResolvedMention]
    let vocabulary: NameVocabulary
    let sentenceText: [Int: String]
    var calls = 0
    var failed = 0

    mutating func read(_ slice: [NumberedSentence], into linked: inout LinkedChapter, canSplit: Bool) async {
        guard !Task.isCancelled, calls < llm.maxCallsPerChapter, let first = slice.first?.index, let last = slice.last?.index else { return }
        let listed = linked.mentions.filter { (first...last).contains($0.sentence) && ($0.form == .description || $0.entity == nil) }
        let request = SliceRequest(
            sentences: slice.map { ModelSentence(index: $0.index, text: $0.text) },
            mentions: listed.enumerated().map { SliceMention(number: $0.offset + 1, text: $0.element.text, sentence: $0.element.sentence, location: $0.element.location) },
            cards: CastCards.cards(for: slice, mentions: earlier + linked.mentions, memory: linked.memory, sentenceText: sentenceText, maxCards: CastCardsKnobs.maxCards)
        )
        calls += 1
        do {
            let reading = try await llm.readSlice(request)
            SliceReadingApplier.apply(reading, request: request, to: &linked, vocabulary: vocabulary)
        } catch .exceededContext where canSplit && slice.count > 1 {
            let half = slice.count / 2
            await read(Array(slice[..<half]), into: &linked, canSplit: false)
            await read(Array(slice[half...]), into: &linked, canSplit: false)
        } catch {
            failed += 1
        }
    }
}
