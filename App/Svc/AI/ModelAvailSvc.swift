import Foundation
import FoundationModels

struct ModelAvailSvc {
    var isFoundationModelsAvailable: Bool { unavailableReason == nil }

    var unavailableReason: String? {
        guard LLMKnobs.isEnabled else { return "off in LLMKnobs.isEnabled" }
        switch SystemLanguageModel.default.availability {
        case .available:
            return nil
        case .unavailable(.deviceNotEligible):
            return "this device does not support Apple Intelligence"
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Apple Intelligence is turned off (Settings → Apple Intelligence & Siri)"
        case .unavailable(.modelNotReady):
            return "the model is not ready yet (still downloading; try again later)"
        case .unavailable:
            return "unavailable for an unknown reason"
        }
    }

    func makeLLMSvc() -> LLMSvc {
        isFoundationModelsAvailable ? LLMSvcFoundation() : LLMSvcUnavailable(reason: unavailableReason ?? "not available")
    }
}
