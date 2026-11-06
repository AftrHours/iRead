import FoundationModels
import OSLog

/// Whether Apple's on-device model really answers. The system can say the model is available while every call
/// still fails (in the Simulator it fails with ModelManagerError 1001), and UnderlineEngine then drops every phrase.
struct ModelCheckSvc {
    private let logger = Logger(subsystem: Logger.appSubsystem, category: "model")

    /// Makes one tiny call to the model.
    func modelAnswers() async -> Bool {
        guard SystemLanguageModel.default.availability == .available else { return false }
        do {
            _ = try await LanguageModelSession().respond(to: "Reply with OK.")
            return true
        } catch {
            logger.error("The on-device model failed a test call, so underlines use rules only: \(String(describing: error), privacy: .public)")
            return false
        }
    }
}
