import Foundation

protocol LLMSvc: Sendable {
    var isAvailable: Bool { get }
    var contextSentenceCount: Int { get }
    var maxCandidates: Int { get }
    var namesPerCall: Int { get }
    var maxCalls: Int { get }

    func allowsCall(callsSoFar: Int) -> Bool
    func groupNames(_ request: NameGroupRequest) async -> [NameGroupChoice]
    func chooseReference(_ request: LinkRequest) async -> LinkChoice?
}

struct LLMSvcUnavailable: LLMSvc {
    var isAvailable: Bool { false }
    var contextSentenceCount: Int { 0 }
    var maxCandidates: Int { 0 }
    var namesPerCall: Int { 1 }
    var maxCalls: Int { 0 }

    func allowsCall(callsSoFar: Int) -> Bool { false }
    func groupNames(_ request: NameGroupRequest) async -> [NameGroupChoice] { [] }
    func chooseReference(_ request: LinkRequest) async -> LinkChoice? { nil }
}
