import Foundation
import Testing
@testable import iRead

@Suite("SymbolPalette")
struct SymbolPaletteTests {
    private let entity = Entity(id: "character-1", name: "Anna", symbolName: "seal.fill", appearances: [], names: ["Anna"])

    @Test("AN-12 an edited symbol wins; otherwise the colour comes from the symbol's index")
    func style() throws {
        let edited = SymbolStyle(systemName: "heart.fill", colorIndex: 2)
        #expect(SymbolPalette.style(for: entity, edited: ["character-1": edited]) == edited)
        let index = try #require(AnalysisMapperKnobs.symbols.firstIndex(of: "seal.fill"))
        #expect(SymbolPalette.style(for: entity, edited: [:]) == SymbolStyle(systemName: "seal.fill", colorIndex: index % 10))
    }

    @Test("AN-13 a colour index past the palette gives the fallback colour")
    func fallbackColor() {
        #expect(SymbolPalette.color(at: 99) == SymbolPaletteKnobs.fallback)
    }
}
