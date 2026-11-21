import Foundation
import UnderlineKit

/// The engine behind `Underlining`: the app asks for underlines and doesn't know which method finds them.
extension UnderlineRepo {
    func engine() async -> any Underlining {
        if let underliner { return underliner }
        let made = await makeUnderliner()
        if let underliner { return underliner }
        underliner = made
        logger.info("Underlines use: \(made.summary, privacy: .public)")
        return made
    }
}
