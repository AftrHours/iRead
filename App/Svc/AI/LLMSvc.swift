import Foundation

protocol LLMSvc: Sendable {
    var isAvailable: Bool { get }
    var contextSentenceCount: Int { get }
    var maxCandidates: Int { get }
    var knobSummary: String { get }

    func allowsCall(callsSoFar: Int) -> Bool
    func groupNames(_ request: NameGroupRequest) async -> NameGroupResult
    func chooseReference(_ request: LinkRequest) async -> LinkChoice?
}

struct LLMSvcUnavailable: LLMSvc {
    let reason: String

    var isAvailable: Bool { false }
    var contextSentenceCount: Int { 0 }
    var maxCandidates: Int { 0 }
    var knobSummary: String { "Foundation Models off: \(reason)" }

    func allowsCall(callsSoFar: Int) -> Bool { false }
    func groupNames(_ request: NameGroupRequest) async -> NameGroupResult { NameGroupResult(groups: [], failedCalls: 0) }
    func chooseReference(_ request: LinkRequest) async -> LinkChoice? { nil }
}
