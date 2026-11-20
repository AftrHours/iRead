import Foundation
import UnderlineEngine

/// The engine as measured (UnderlineEngine R8): rules only, with `embedding` (`.contextual` in the app).
extension UnderlineRepo {
    func engine() async -> UnderlineCtrl {
        if let underlineCtrl { return underlineCtrl }
        let made = await UnderlineCtrl.make(model: .rulesOnly, embedding: embedding)
        if let underlineCtrl { return underlineCtrl }
        underlineCtrl = made
        logger.info("Underlines use rules with the \(made.embeddingEngine.rawValue, privacy: .public) embedding")
        return made
    }

    func modelAnswers() async -> Bool {
        guard let modelCheckSvc else { return false }
        return await Task { await modelCheckSvc.modelAnswers() }.value
    }
}
