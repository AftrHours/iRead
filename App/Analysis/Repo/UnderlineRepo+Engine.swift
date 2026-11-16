import Foundation
import UnderlineEngine

/// Which engine underlines: Foundation Models, or rules alone when the model doesn't answer.
extension UnderlineRepo {
    /// The system can report the model available while every call fails, and the engine then drops every phrase,
    /// so the model is tried once first and the engine falls back to rules.
    func engine() async -> UnderlineCtrl {
        if let underlineCtrl { return underlineCtrl }
        let canUseModel = await modelAnswers()
        if let underlineCtrl { return underlineCtrl }
        let made = UnderlineCtrl(model: canUseModel ? .automatic : .rulesOnly)
        underlineCtrl = made
        return made
    }

    /// Its own task, so a chapter stopped while the model is tried (the reader turned to another chapter) doesn't cancel
    /// the call and count as the model failing, which would leave the app on rules until it is opened again.
    func modelAnswers() async -> Bool {
        guard let modelCheckSvc else { return false }
        return await Task { await modelCheckSvc.modelAnswers() }.value
    }
}
