import Foundation

enum DecidedBy: Sendable {
    case rule
    case model
}

struct EntityName: Sendable {
    let text: String
    let key: String
    let sinceSentence: Int
}

struct MergeEdge: Sendable {
    let into: Int
    let mergedAtSentence: Int
    let decidedBy: DecidedBy
}

struct ResolvedEntity: Sendable {
    let key: Int
    var names: [EntityName]
    var label: String
    let introSentence: Int
    var mergeEdges: [MergeEdge]
}
