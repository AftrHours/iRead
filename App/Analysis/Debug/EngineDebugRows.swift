#if DEBUG
import SwiftUI

struct EngineDebugRow: Identifiable {
    let label: String
    let value: String

    var id: String { label }
}

struct EngineDebugUnderline: Identifiable {
    let id: String
    let label: String
    let sentence: AttributedString
    let reference: String
    let referenceLabel: String
}

/// The phrases dropped for one reason.
struct EngineDebugDrops: Identifiable {
    let reason: String
    let phrases: [String]

    var id: String { reason }
}

struct EngineDebugChapter: Identifiable {
    let id: Int
    let title: String
    let status: String
    let underlines: [EngineDebugUnderline]
    let drops: [EngineDebugDrops]
}
#endif
