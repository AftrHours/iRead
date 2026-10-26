import Foundation

struct Entity: Sendable {
    let id: String
    let name: String
    let symbolName: String
    let appearances: [ContextPassage]
    let names: [String]
}
