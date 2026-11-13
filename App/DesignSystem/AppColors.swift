import SwiftUI
import UIKit

/// Semantic color tokens shared across app features.
enum AppColors {
    static let backgroundPrimary = adaptive(light: 0xF3F4FF, dark: 0x0C0C24)
    static let cardBackground = Color(hex: 0xFFFDFB)
    static let cardProgressTrack = Color(hex: 0xFFD6B2)
    static let readerBackground = adaptive(light: 0xFFFFFF, dark: 0x000000)
    static let readerReferencePanel = adaptive(light: 0xFFF6ED, dark: 0xFFF6ED)
    static let actionPrimary = Color(hex: 0xFFA248)
    static let cardTextPrimary = Color(hex: 0x0C0C24)
    static let cardTextSecondary = Color(hex: 0x4F5297)
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
    static let menuTextMuted = adaptive(light: 0xBFBFBF, dark: 0x9096D1)
    static let accountSignIn = adaptive(light: 0x4F5297, dark: 0x9096D1)
    static let accountSignOut = adaptive(light: 0xFF383C, dark: 0xFF4245)
    static let popoverQuoteText = adaptive(light: 0x0C0C24, dark: 0xFFFDFB)

    static let settingsText = adaptive(light: 0x1A1A1A, dark: 0xFFFDFB)

    // Reading Theme & Settings sheet.
    static let settingsSheetBackground = adaptive(light: 0xFBFBFF, dark: 0x0C0C24)
    static let settingsSecondaryText = adaptive(light: 0x3C3C43, dark: 0xFFFFFF, lightAlpha: 0.8, darkAlpha: 0.8)
    static let settingsSliderTrack = adaptive(light: 0x787878, dark: 0xFFFFFF, lightAlpha: 0.6, darkAlpha: 0.6)
    // In the design, not drawn yet: SwiftUI's Slider doesn't let an app colour its step dots or its knob.
    static let settingsSliderTick = adaptive(light: 0x787878, dark: 0xFFFFFF, lightAlpha: 0.6, darkAlpha: 0.6)
    static let settingsSliderKnob = adaptive(light: 0xFFFFFF, dark: 0xFFFFFF)
    static let settingsMenuButtonFill = adaptive(light: 0x444444, dark: 0x999999, lightAlpha: 0.6, darkAlpha: 0.17)
    /// The design uses the same grey in light and dark.
    static let settingsResetFill = adaptive(light: 0x444444, dark: 0x444444, lightAlpha: 0.17, darkAlpha: 0.17)
    static let settingsResetText = adaptive(light: 0x1A1A1A, dark: 0xF5F5F5)
    /// The hairline between the Layout Options rows.
    static let settingsDivider = adaptive(light: 0xE6E6E6, dark: 0x1A1A1A)
    /// The iPad panel's drag handle. Faint on purpose, as in the design.
    static let settingsGrabber = adaptive(light: 0xCCCCCC, dark: 0x333333)
    /// The outline around the chosen theme tile.
    static let settingsTileSelectedBorder = adaptive(light: 0x000000, dark: 0xFFFDFB)
    /// The Original theme's tile. Its page is the system background, which would vanish into the sheet.
    static let settingsOriginalTile = adaptive(light: 0xF2F1F1, dark: 0x000000)

    /// A theme's swatch in Reading Theme & Settings: the page's own colour, except Original, whose page is the system
    /// background and would vanish into the sheet, so it gets settingsOriginalTile.
    static func settingsThemeTile(for theme: ReadingTheme) -> Color {
        theme == .original ? settingsOriginalTile : Color(PageTextStyle.backgroundColor(for: theme))
    }

    private static func adaptive(light: UInt32, dark: UInt32, lightAlpha: CGFloat = 1, darkAlpha: CGFloat = 1) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark, alpha: darkAlpha) : UIColor(hex: light, alpha: lightAlpha)
        })
    }
}

private extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: alpha)
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
