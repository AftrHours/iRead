import Foundation

struct CastMemory: Sendable, Codable {
    var entities: [ResolvedEntity]
    var traits: [Int: [CharacterTrait]]
    var symbols: [Int: SymbolAssignment]

    static let empty = CastMemory(entities: [], traits: [:], symbols: [:])
}
