import Foundation

struct NameGroupRequest: Sendable {
    let names: [String]
    let sentences: [ModelSentence]
}
