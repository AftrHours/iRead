import Foundation

enum DecidedBy: Sendable, Codable {
    case rule
    case model
}

struct EntityName: Sendable, Codable {
    let text: String
    let key: String
    let sinceSentence: Int
}

struct MergeEdge: Sendable, Codable {
    let into: Int
    let mergedAtSentence: Int
    let decidedBy: DecidedBy
}

struct ResolvedEntity: Sendable, Codable {
    let key: Int
    var names: [EntityName]
    var label: String
    let introSentence: Int
    var mergeEdges: [MergeEdge]
}
