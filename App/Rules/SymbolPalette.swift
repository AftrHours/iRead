import UIKit

enum SymbolPaletteKnobs {
    static let colors: [UIColor] = [
        .systemRed, .systemBlue, .systemGreen, .systemOrange, .systemPurple, .systemTeal,
        .systemPink, .systemIndigo, .systemBrown, .systemCyan, .systemMint, .systemYellow
    ]
    static let fallback = UIColor.label
}

enum SymbolPalette {
    static func color(forSymbol symbolName: String) -> UIColor {
        guard let index = AnalysisMapperKnobs.symbols.firstIndex(of: symbolName) else { return SymbolPaletteKnobs.fallback }
        return SymbolPaletteKnobs.colors[index % SymbolPaletteKnobs.colors.count]
    }
}
