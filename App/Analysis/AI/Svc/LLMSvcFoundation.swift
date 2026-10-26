import Foundation
import FoundationModels

enum Sampling: Sendable {
    case greedy

    case topK(Int, seed: UInt64?)

    case probability(Double, seed: UInt64?)
}

enum LLMKnobs {
    static let isEnabled = true

    static let groupNamesInstructions = """
        You group names that belong to the same person in a novel. Use only the numbered sentences given, \
        never what you may know about the book. Group names only when a given sentence shows they are the same person, \
        and give that sentence's number. Leave every other name ungrouped.
        """
    static let chooseReferenceInstructions = """
        You identify which character a phrase in a novel refers to. Use only the numbered sentences given, \
        never what you may know about the book. Answer with the number of the candidate the phrase refers to, \
        or -1 if the sentences do not make it clear. Also give the number of the sentence that shows it. Be conservative.
        """

    static let contextSentenceCount = 3
    static let maxCandidates = 5

    static let maxNamesPerCall = 12

    static let sampling: Sampling = .greedy

    static let temperature: Double? = nil

    static let maxChooseReferenceTokens = 64
    static let maxGroupNamesTokens = 512

    static let maxCallsPerRun = 150

    static func chooseReferencePrompt(_ request: LinkRequest) -> String {
        let candidates = request.candidates.enumerated().map { "\($0.offset). \($0.element.label)" }.joined(separator: "\n")
        return """
            Sentences:
            \(numbered(request.sentences))

            Phrase: "\(request.mention.text)" (in sentence \(request.mention.sentence))

            Candidates:
            \(candidates)
            """
    }

    static func groupNamesPrompt(names: [String], sentences: [ModelSentence]) -> String {
        """
        Sentences:
        \(numbered(sentences))

        Names: \(names.joined(separator: ", "))
        """
    }

    private static func numbered(_ sentences: [ModelSentence]) -> String {
        sentences.map { "[\($0.index)] \($0.text)" }.joined(separator: "\n")
    }
}

struct LLMSvcFoundation: LLMSvc {
    var isAvailable: Bool { ModelAvailSvc().isFoundationModelsAvailable }
    var contextSentenceCount: Int { LLMKnobs.contextSentenceCount }
    var maxCandidates: Int { LLMKnobs.maxCandidates }

    func allowsCall(callsSoFar: Int) -> Bool {
        isAvailable && callsSoFar < LLMKnobs.maxCallsPerRun
    }

    func chooseReference(_ request: LinkRequest) async -> LinkChoice? {
        let session = LanguageModelSession(instructions: LLMKnobs.chooseReferenceInstructions)
        guard let answer = try? await session.respond(to: LLMKnobs.chooseReferencePrompt(request), generating: ChooseReferenceAnswer.self,
                                                      options: Self.options(maximumTokens: LLMKnobs.maxChooseReferenceTokens))
        else { return nil }
        return LinkChoice(candidateIndex: answer.content.candidate, evidenceSentence: answer.content.evidenceSentence)
    }

    func groupNames(_ request: NameGroupRequest) async -> [NameGroupChoice] {
        var groups: [NameGroupChoice] = []
        for start in stride(from: 0, to: request.names.count, by: LLMKnobs.maxNamesPerCall) {
            let names = Array(request.names[start..<min(start + LLMKnobs.maxNamesPerCall, request.names.count)])
            let session = LanguageModelSession(instructions: LLMKnobs.groupNamesInstructions)
            guard let answer = try? await session.respond(to: LLMKnobs.groupNamesPrompt(names: names, sentences: request.sentences),
                                                          generating: GroupNamesAnswer.self,
                                                          options: Self.options(maximumTokens: LLMKnobs.maxGroupNamesTokens))
            else { continue }
            groups += answer.content.groups.map { NameGroupChoice(names: $0.names, evidenceSentence: $0.evidenceSentence) }
        }
        return groups
    }

    private static func options(maximumTokens: Int) -> GenerationOptions {
        let sampling: GenerationOptions.SamplingMode
        switch LLMKnobs.sampling {
        case .greedy: sampling = .greedy
        case .topK(let k, let seed): sampling = .random(top: k, seed: seed)
        case .probability(let p, let seed): sampling = .random(probabilityThreshold: p, seed: seed)
        }
        return GenerationOptions(samplingMode: sampling, temperature: LLMKnobs.temperature, maximumResponseTokens: maximumTokens)
    }
}
