import Foundation

enum LLMFailure: Error {
    case exceededContext
    case refused
    case unavailable
    case other
}

protocol LLMSvc: Sendable {
    var isAvailable: Bool { get }
    var contextSize: Int { get }
    var maxCallsPerChapter: Int { get }

    func prewarm()
    func readSlice(_ request: SliceRequest) async throws(LLMFailure) -> SliceReading
}

struct LLMSvcUnavailable: LLMSvc {
    var isAvailable: Bool { false }
    var contextSize: Int { 0 }
    var maxCallsPerChapter: Int { 0 }

    func prewarm() {}
    func readSlice(_ request: SliceRequest) async throws(LLMFailure) -> SliceReading { throw .unavailable }
}
