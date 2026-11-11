import SwiftUI
import UIKit

/// Semantic color tokens shared across app features.
enum AppColors {
    static let backgroundPrimary = adaptive(light: 0xF3F4FF, dark: 0x0C0C24)
    static let readerBackground = adaptive(light: 0xFFFFFF, dark: 0x000000)
    static let readerReferencePanel = adaptive(light: 0xFFF6ED, dark: 0xFFF6ED)
    static let actionPrimary = Color(hex: 0xFFA248)
    static let menuBackground = adaptive(light: 0xF3F4FF, dark: 0x1E1E48)
    static let popoverBackground = adaptive(light: 0xFFFFFF, dark: 0x1E1E48)
    static let popoverQuoteBackground = adaptive(light: 0xFFF6ED, dark: 0x1E1E48)
    static let settingsBackground = adaptive(light: 0xF8F8F8, dark: 0x0C0C24)
    static let settingsControlBackground = adaptive(light: 0xF3F4FF, dark: 0x1E1E48)
    static let popoverQuoteIconBackground = adaptive(light: 0x333375, dark: 0xCDD2F4)
    static let popoverQuoteIcon = adaptive(light: 0xFFF6ED, dark: 0x1E1E48)

    static let textPrimary = adaptive(light: 0x0C0C24, dark: 0xF3F4FF)
    static let textSecondary = adaptive(light: 0x4F5297, dark: 0xCDD2F4)
    static let readerText = adaptive(light: 0x1A1A1A, dark: 0xFFFFFF)
    static let readerReference = adaptive(light: 0x1A1A1A, dark: 0xFFFFFF)
    static let textAccent = adaptive(light: 0xB57333, dark: 0xFFA248)
    static let menuText = adaptive(light: 0x1A1A1A, dark: 0xF5F5F5)
    static let menuTextMuted = adaptive(light: 0xBEBEBF, dark: 0x9096D1)
    static let accountSignIn = adaptive(light: 0x4F5297, dark: 0x9096D1)
    static let accountSignOut = adaptive(light: 0xFF383C, dark: 0xFF4245)
    static let popoverQuoteText = adaptive(light: 0x0C0C24, dark: 0xFFFDFB)
    static let settingsText = adaptive(light: 0x1A1A1A, dark: 0xFFFDFB)

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}

private extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: 1)
    }
}
