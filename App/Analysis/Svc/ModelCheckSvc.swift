import Foundation
import FoundationModels

struct ModelCheckSvc {
    /// Asks the model something small. `availability` can report yes while every call fails.
    func modelAnswers() async -> Bool {
        (try? await LanguageModelSession().respond(to: "Say hi")) != nil
    }
}
