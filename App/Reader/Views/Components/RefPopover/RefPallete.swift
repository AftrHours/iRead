import SwiftUI
import UIKit

/// The reference popover's colors, one pair per color: the design's light card and its dark card.
/// They follow the system appearance, like the popover itself. Estimated by eye from the design, so adjust freely.
enum RefPalette {
    /// Card and popover arrow.
    static let card = adaptive(light: 0xFFFFFF, dark: 0x1D1A47)
    /// Box behind the quote.
    static let quoteFill = adaptive(light: 0xF2F2FD, dark: 0x4F5094)
    /// Title and quote text.
    static let text = adaptive(light: 0x1D1A47, dark: 0xFFFFFF)
    /// Quote icon tile. Dark in the light card, light in the dark card.
    static let tileFill = adaptive(light: 0x33307A, dark: 0xC5C8F0)
    /// The quote icon drawn on `tileFill`.
    static let onTile = adaptive(light: 0xFFFFFF, dark: 0x1D1A47)
    /// Chapter and page chip, lavender in both cards.
    static let chipFill = adaptive(light: 0xCED1F1, dark: 0xC5C8F0)
    /// Text on `chipFill`.
    static let onChip = adaptive(light: 0x1D1A47, dark: 0x1D1A47)
    /// Thumbs up and down.
    static let control = adaptive(light: 0x4546A3, dark: 0xFFFFFF)
    /// Jump to Passage button, orange in both cards.
    static let jumpFill = adaptive(light: 0xF2A65A, dark: 0xF2A65A)
    /// Text on the Jump to Passage button.
    static let onJump = adaptive(light: 0x1D1A47, dark: 0x1D1A47)

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(refPaletteHex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

private extension UIColor {
    convenience init(refPaletteHex hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

/// Both cards side by side, so the pairs can be compared.
#Preview("Palette") {
    let swatches: [(String, Color)] = [
        ("card", RefPalette.card),
        ("quoteFill", RefPalette.quoteFill),
        ("text", RefPalette.text),
        ("tileFill", RefPalette.tileFill),
        ("onTile", RefPalette.onTile),
        ("chipFill", RefPalette.chipFill),
        ("onChip", RefPalette.onChip),
        ("control", RefPalette.control),
        ("jumpFill", RefPalette.jumpFill),
        ("onJump", RefPalette.onJump)
    ]
    HStack(spacing: 0) {
        ForEach([ColorScheme.light, .dark], id: \.self) { scheme in
            VStack(alignment: .leading, spacing: 8) {
                ForEach(swatches, id: \.0) { name, color in
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(color)
                            .stroke(.gray.opacity(0.4))
                            .frame(width: 44, height: 28)
                        Text(name)
                            .font(.callout.monospaced())
                            .foregroundStyle(scheme == .dark ? .white : .black)
                    }
                }
            }
            .padding()
            .background(scheme == .dark ? Color.black : Color.white)
            .environment(\.colorScheme, scheme)
        }
    }
}
