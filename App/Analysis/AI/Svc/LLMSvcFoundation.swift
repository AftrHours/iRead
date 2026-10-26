import Foundation
import FoundationModels

enum Sampling: Sendable {
    case greedy

    case topK(Int, seed: UInt64?)

    case probability(Double, seed: UInt64?)
}

enum LLMKnobs {
    static let isEnabled = true

    static let sliceInstructions = """
        You read a passage of a novel and keep track of its characters. You get numbered sentences, a list of \
        mentions to decide, and cards for the characters known so far. For each listed mention, give the card number \
        of the character it refers to, or 0 when it is not a character or the passage does not make it clear. List \
        character names in the passage that are missing from the mention list, copied exactly. List pairs of names \
        that belong to the same person; you may use general knowledge of name forms such as nicknames. List short \
        descriptions of characters, copied exactly from the passage. Give a sentence number for every answer. Decide \
        who is who only from the cards and the sentences given. Be conservative and leave out anything unsure.
        """

    static let maxCallsPerChapter = 40

    static let sampling: Sampling = .greedy

    static let temperature: Double? = nil

    static let maxSliceTokens = 1000

    static func slicePrompt(_ request: SliceRequest) -> String {
        let cards = request.cards.map { card in
            var line = "\(card.number). \(card.name)"
            if !card.aliases.isEmpty { line += " (also: \(card.aliases.joined(separator: ", ")))" }
            if !card.traits.isEmpty { line += "; \(card.traits.joined(separator: "; "))" }
            if !card.intro.isEmpty { line += "; first seen: \(card.intro)" }
            return line
        }.joined(separator: "\n")
        let mentions = request.mentions.map { "\($0.number). \"\($0.text)\" in sentence \($0.sentence)" }.joined(separator: "\n")
        return """
            Sentences:
            \(request.sentences.map { "[\($0.index)] \($0.text)" }.joined(separator: "\n"))

            Mentions to decide:
            \(mentions.isEmpty ? "none" : mentions)

            Character cards:
            \(cards.isEmpty ? "none" : cards)
            """
    }
}

struct LLMSvcFoundation: LLMSvc {
    var isAvailable: Bool { ModelAvailSvc().isFoundationModelsAvailable }
    var contextSize: Int { SystemLanguageModel.default.contextSize }
    var maxCallsPerChapter: Int { LLMKnobs.maxCallsPerChapter }

    func prewarm() {
        LanguageModelSession(instructions: LLMKnobs.sliceInstructions).prewarm()
    }

    func readSlice(_ request: SliceRequest) async throws(LLMFailure) -> SliceReading {
        let session = LanguageModelSession(instructions: LLMKnobs.sliceInstructions)
        let answer: SliceReadAnswer
        do {
            answer = try await session.respond(to: LLMKnobs.slicePrompt(request), generating: SliceReadAnswer.self,
                                               options: Self.options(maximumTokens: LLMKnobs.maxSliceTokens)).content
        } catch {
            throw Self.failure(for: error)
        }
        return SliceReading(
            assignments: answer.assignments.map { MentionAssignment(mention: $0.mention, card: $0.card == 0 ? nil : $0.card, evidence: $0.sentence) },
            missedNames: answer.missedNames.map { NamedSpan(text: $0.name, sentence: $0.sentence) },
            sameNames: answer.sameNames.map { NamePair(first: $0.first, second: $0.second, evidence: $0.sentence) },
            traits: answer.traits.map { TraitNote(card: $0.card, text: $0.text, sentence: $0.sentence) }
        )
    }

    private static func failure(for error: any Error) -> LLMFailure {
        if #available(iOS 27.0, macOS 27.0, *), let error = error as? LanguageModelError {
            switch error {
            case .contextSizeExceeded: return .exceededContext
            case .guardrailViolation, .refusal: return .refused
            default: return .other
            }
        }
        if let error = error as? LanguageModelSession.GenerationError {
            switch error {
            case .exceededContextWindowSize: return .exceededContext
            case .guardrailViolation, .refusal: return .refused
            default: return .other
            }
        }
        return .other
    }

    private static func options(maximumTokens: Int) -> GenerationOptions {
        let sampling: GenerationOptions.SamplingMode
        switch LLMKnobs.sampling {
        case .greedy: sampling = .greedy
        case .topK(let k, let seed): sampling = .random(top: k, seed: seed)
        case .probability(let p, let seed): sampling = .random(probabilityThreshold: p, seed: seed)
        }
        return GenerationOptions(sampling: sampling, temperature: LLMKnobs.temperature, maximumResponseTokens: maximumTokens)
    }
}
