#if DEBUG
import SwiftUI

struct EngineDebugRow: Identifiable {
    let label: String
    let value: String

    var id: String { label }
}

struct EngineDebugSection: Identifiable {
    let title: String
    let rows: [EngineDebugRow]

    var id: String { title }
}

struct EngineDebugCharacter: Identifiable {
    let id: String
    let name: String
    let symbolName: String
    let color: Color
    let names: String
    let mentionCount: Int
    let firstSeen: String
}

struct EngineDebugSentence: Identifiable {
    let id: Int
    let text: AttributedString
    let links: [String]
}
#endif
