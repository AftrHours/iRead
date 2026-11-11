import SwiftUI
import UIKit

/// Colors used by the Hi-Fi library screens. The pair follows the light and dark
/// library frames in Figma while leaving the reader's independent page themes alone.
enum LibraryPalette {
    static let page = adaptive(light: 0xF4F4FC, dark: 0x141331)
    static let card = adaptive(light: 0xFFFFFF, dark: 0x1D1A47)
    static let primaryText = adaptive(light: 0x283858, dark: 0xF7F6FF)
    static let secondaryText = adaptive(light: 0x47719E, dark: 0xC1CBE5)
    static let progressTrack = adaptive(light: 0xFFD0A0, dark: 0x423D6B)
    static let progressFill = Color(hex: 0xF2963F)
    static let addButton = Color(hex: 0xF69A3B)
    static let controlFill = Color(hex: 0xA8D0FF)
    static let divider = adaptive(light: 0xD9DCEC, dark: 0x39365F)
    static let searchFill = adaptive(light: 0xFFFFFF, dark: 0x27244E)
    static let color: UInt32 = 0xA8D0FF
    
    
    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

private extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
