import Foundation

/// How a character's symbol looks: an SF Symbol name and an index into `SymbolPaletteKnobs.colors`.
struct SymbolStyle: Codable, Equatable, Sendable {
    var systemName: String
    var colorIndex: Int
}
