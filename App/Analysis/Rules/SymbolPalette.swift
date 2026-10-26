import UIKit

enum SymbolPaletteKnobs {
    /// The colour row of the Edit Symbol sheet, in order.
    static let colors: [UIColor] = [
        .systemRed, .systemOrange, .systemYellow, .systemGreen, .systemMint,
        .systemTeal, .systemCyan, .systemBlue, .systemIndigo, .systemPurple
    ]
    static let shapes = [
        "circle.fill", "square.fill", "triangle.fill", "diamond.fill",
        "rhombus.fill", "pentagon.fill", "hexagon.fill", "octagon.fill"
    ]
    static let icons = ["heart.fill", "star.fill", "moon.fill", "sparkle", "bolt.fill", "drop.fill", "leaf.fill"]
    static let fallback = UIColor.label
}

enum SymbolPalette {
    static func color(at index: Int) -> UIColor {
        SymbolPaletteKnobs.colors.indices.contains(index) ? SymbolPaletteKnobs.colors[index] : SymbolPaletteKnobs.fallback
    }

    /// The reader's own choice if they edited it, otherwise the symbol the analysis gave and a colour picked from it.
    static func style(for entity: Entity, edited: [String: SymbolStyle]) -> SymbolStyle {
        if let style = edited[entity.id] {
            return style
        }
        let index = AnalysisMapperKnobs.symbols.firstIndex(of: entity.symbolName) ?? 0
        return SymbolStyle(systemName: entity.symbolName, colorIndex: index % SymbolPaletteKnobs.colors.count)
    }
}
