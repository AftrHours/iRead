import SwiftUI
import UIKit

/// Semantic color tokens shared across app features. Each one points at a PrimaryColor for light and for dark.
/// A value that isn't in the palette yet stays a hex until design adds it.
/// Figma lists Background, Background — Dark, Text and Text — Dark separately. Here each token holds both modes
/// (`light:` and `dark:`), so the Figma frames come out as two groups: Background and Text.
enum AppColors {
    // MARK: - Background (Figma: Background, Background — Dark)

    static let bgPrimary = adaptive(light: PrimaryColor.purple50, dark: PrimaryColor.purple900)
    static let readerBg=adaptive(light: PrimaryColor.white0, dark: PrimaryColor.black)
    static let readerReferencePanel = adaptive(light: PrimaryColor.orange50, dark: PrimaryColor.orange50)
    static let actionPrimary = Color(hex: PrimaryColor.orange500)
    static let actionSecondary = adaptive(light: PrimaryColor.neutral100, dark: PrimaryColor.purple800)
    static let menuBg = adaptive(light: PrimaryColor.purple50, dark: PrimaryColor.purple800)
    static let settingsBg = adaptive(light: PrimaryColor.neutral100, dark: PrimaryColor.purple900)
    static let settingsControlBg = adaptive(light: PrimaryColor.purple50, dark: PrimaryColor.purple800)
    static let settingSliderFill = adaptive(light: PrimaryColor.orange500, dark: PrimaryColor.orange500)
    static let settingSliderTrack = adaptive(light: PrimaryColor.neutral500, dark: PrimaryColor.white0,
                                             lightAlpha: 0.6, darkAlpha: 0.6)
    static let settingSliderTick = adaptive(light: PrimaryColor.neutral500, dark: PrimaryColor.white0,
                                            lightAlpha: 0.6, darkAlpha: 0.6)
    static let settingSliderKnob = adaptive(light: PrimaryColor.white0, dark: PrimaryColor.white0)
    static let popoverQuoteIconBg = adaptive(light: PrimaryColor.purple700, dark: PrimaryColor.purple200)
    static let popoverQuoteIcon = adaptive(light: PrimaryColor.orange50, dark: PrimaryColor.purple800)
    static let cardBg = Color(hex: PrimaryColor.white50)

    // MARK: - Text (Figma: Text, Text — Dark)

    static let textPrimary = adaptive(light: PrimaryColor.purple900, dark: PrimaryColor.purple50)
    static let textSecondary = adaptive(light: PrimaryColor.purple600, dark: PrimaryColor.purple200)
    static let readerText = adaptive(light: PrimaryColor.neutral900, dark: PrimaryColor.white0)
    static let readerReference = adaptive(light: PrimaryColor.neutral900, dark: PrimaryColor.white0)
    static let textAccent = adaptive(light: PrimaryColor.orange700, dark: PrimaryColor.orange500)
    static let menuText = adaptive(light: PrimaryColor.neutral900, dark: PrimaryColor.neutral50)
    static let menuTextMuted = adaptive(light: PrimaryColor.neutral300, dark: PrimaryColor.purple400)
    static let accountSignIn = adaptive(light: PrimaryColor.purple600, dark: PrimaryColor.purple400)
    static let accountSignOut = adaptive(light: PrimaryColor.red500, dark: PrimaryColor.red400)
    static let popoverQuoteText = adaptive(light: PrimaryColor.purple900, dark: PrimaryColor.white50)
    static let settingsText = adaptive(light: PrimaryColor.neutral900, dark: PrimaryColor.white50)
    //
    static let settingsSliderText = adaptive(light: PrimaryColor.neutral700, dark: PrimaryColor.white0, lightAlpha: 0.8, darkAlpha: 0.8)
    static let cardTextPrimary = Color(hex: PrimaryColor.purple900)
    static let cardTextSecondary = Color(hex: PrimaryColor.purple600)

    // Library and Search
    static let libraryListDivider = adaptive(light: PrimaryColor.purple200, dark: PrimaryColor.purple200, darkAlpha: 0.16)
    static let progressBarBg = adaptive(light: PrimaryColor.orange200, dark: PrimaryColor.orange200)
    static let progressBarLine = adaptive(light: PrimaryColor.orange500, dark: PrimaryColor.orange500)
    static let cardMenuIcon = Color(hex: 0xB2B5E8)
    static let searchBackground = adaptive(light: 0xE0E0EA, dark: 0x32324B)
    static let searchMutedForeground = Color(hex: 0x6A6A83)
    static let libraryEmptyMessageText = adaptive(light: PrimaryColor.purple500, dark: PrimaryColor.purple200)
    static let searchEmptyMessageText = adaptive(light: PrimaryColor.purple500, dark: PrimaryColor.purple300)

    // Reader
    static let readerHighlight = adaptiveUIColor(light: PrimaryColor.purple200, dark: PrimaryColor.purple200,
                                                 lightAlpha: 0.6, darkAlpha: 0.3)
    static let readingProgressBarbG = adaptive(light: PrimaryColor.purple200, dark: PrimaryColor.orange200)
    static let readingProgressBarLine = adaptive(light: PrimaryColor.purple600, dark: PrimaryColor.orange500)
    static let readingProgressBarMark = adaptive(light: PrimaryColor.orange500, dark: PrimaryColor.purple600)

    // Reference popover tokens that the Semantic tokens frame doesn't list yet, from the popover design's color list.
    static let popoverBg = adaptive(light: PrimaryColor.white0, dark: PrimaryColor.purple800)
    static let popoverQuoteBg = adaptive(light: PrimaryColor.orange50, dark: PrimaryColor.purple800)
    static let popoverLocationBg = adaptive(light: PrimaryColor.purple200, dark: PrimaryColor.purple300)
    static let popoverPassageBg = adaptive(light: PrimaryColor.purple50, dark: PrimaryColor.purple600)
    static let popoverPassageText = adaptive(light: PrimaryColor.purple900, dark: PrimaryColor.white50)
    static let popoverLocationText = adaptive(light: PrimaryColor.purple900, dark: PrimaryColor.purple900)
    static let popoverFeedbackIcon = adaptive(light: PrimaryColor.purple600, dark: PrimaryColor.purple50)
    static let actionPrimaryText = adaptive(light: PrimaryColor.neutral900, dark: PrimaryColor.neutral900)
    
    // Reading Theme & Settings sheet
    static let sheetbg = adaptive(light: PrimaryColor.purple25, dark: PrimaryColor.purple900)
    static let settingsMenuButtonFill = adaptive(light: 0x444444, dark: 0x999999, lightAlpha: 0.6, darkAlpha: 0.17)
    /// The design uses the same grey in light and dark.
    static let settingsResetFill = adaptive(light: 0x444444, dark: 0x444444, lightAlpha: 0.17, darkAlpha: 0.17)
    static let settingsResetText = adaptive(light: PrimaryColor.neutral900, dark: PrimaryColor.neutral50)
    /// The hairline between the Layout Options rows.
    static let settingsDivider = adaptive(light: 0xE6E6E6, dark: PrimaryColor.neutral900)
    /// The iPad panel's drag handle. Faint on purpose, as in the design.
    static let settingsGrabber = adaptive(light: 0xCCCCCC, dark: 0x333333)
    /// The outline around the chosen theme tile.
    static let settingsTileSelectedBorder = adaptive(light: PrimaryColor.black, dark: PrimaryColor.white50)
    /// The Original theme's tile. Its page is the system background, which would vanish into the sheet.
    static let settingsOriginalTile = adaptive(light: 0xF2F1F1, dark: PrimaryColor.black)

    /// A theme's swatch in Reading Theme & Settings: the page's own colour, except Original, whose page is the system
    /// background and would vanish into the sheet, so it gets settingsOriginalTile.
    static func settingsThemeTile(for theme: ReadingTheme) -> Color {
        theme == .original ? settingsOriginalTile : Color(PageTextStyle.backgroundColor(for: theme))
    }

    private static func adaptive(light: UInt32, dark: UInt32, lightAlpha: CGFloat = 1, darkAlpha: CGFloat = 1) -> Color {
        Color(uiColor: adaptiveUIColor(light: light, dark: dark, lightAlpha: lightAlpha, darkAlpha: darkAlpha))
    }

    private static func adaptiveUIColor(light: UInt32, dark: UInt32, lightAlpha: CGFloat = 1, darkAlpha: CGFloat = 1) -> UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark, alpha: darkAlpha) : UIColor(hex: light, alpha: lightAlpha)
        }
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
