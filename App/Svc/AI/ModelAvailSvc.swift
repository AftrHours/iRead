import Foundation
import FoundationModels

struct ModelAvailSvc {
    var isFoundationModelsAvailable: Bool {
        guard LLMKnobs.isEnabled, case .available = SystemLanguageModel.default.availability else { return false }
        return true
    }

    func makeLLMSvc() -> LLMSvc {
        isFoundationModelsAvailable ? LLMSvcFoundation() : LLMSvcUnavailable()
    }
}
