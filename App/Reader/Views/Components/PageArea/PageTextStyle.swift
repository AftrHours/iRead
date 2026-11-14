import UIKit

enum PageTextStyle {
    static func font(settings: ReadingSettings) -> UIFont {
        font(for: settings.theme, size: settings.textSize)
    }

    /// The Apple Books font of each theme. Falls back to the system font if one is missing.
    static func font(for theme: ReadingTheme, size: CGFloat) -> UIFont {
        let name: String? = switch theme {
        case .original, .bold: nil
        case .quiet: "IowanOldStyle-Roman"
        case .paper: "Charter-Roman"
        case .calm: "Athelas-Regular"
        case .focus: "Seravek"
        }
        if let name, let font = UIFont(name: name, size: size) {
            return font
        }
        return .systemFont(ofSize: size, weight: theme == .bold ? .bold : .regular)
    }

    /// Light and dark like the rest of the reader: the view's light or dark style picks one.
    static func textColor(for theme: ReadingTheme) -> UIColor {
        switch theme {
        case .original: .label
        case .quiet: UIColor(hex: 0x8E8E90)
        case .paper: adaptive(light: 0x1C1C1E, dark: 0xF2F2F0)
        case .bold: adaptive(light: 0x000000, dark: 0xEFEFF2)
        case .calm: adaptive(light: 0x413524, dark: 0xFCEBD9)
        case .focus: adaptive(light: 0x1A1A1A, dark: 0xFFF9E9)
        }
    }

    static func backgroundColor(for theme: ReadingTheme) -> UIColor {
        switch theme {
        case .original: .systemBackground
        case .quiet: adaptive(light: 0x4A4A4C, dark: 0x000000)
        case .paper: adaptive(light: 0xEDEDED, dark: 0x1C1C1D)
        case .bold: adaptive(light: 0xF2F2F2, dark: 0x000000)
        case .calm: adaptive(light: 0xF1E4CA, dark: 0x423B2F)
        case .focus: adaptive(light: 0xFFFCF1, dark: 0x17160B)
        }
    }

    /// Quiet's light page is dark grey, so its controls stay light on it either way.
    static func isDarkPage(_ theme: ReadingTheme, isDarkMode: Bool) -> Bool {
        isDarkMode || theme == .quiet
    }

    /// The page's text with every setting applied. The pager and the page view both use it, so pages break where they are drawn.
    static func attributedText(_ string: String, settings: ReadingSettings) -> NSMutableAttributedString {
        let text = NSMutableAttributedString(string: string, attributes: attributes(settings: settings))
        guard settings.wordSpacingPercent > 0 else { return text }
        let font = font(settings: settings)
        let spaceWidth = (" " as NSString).size(withAttributes: [.font: font]).width
        let wordKern = characterKern(settings: settings) + spaceWidth * CGFloat(settings.wordSpacingPercent) / 100
        let nsString = string as NSString
        var searchRange = NSRange(location: 0, length: nsString.length)
        while true {
            let space = nsString.range(of: " ", options: .literal, range: searchRange)
            guard space.location != NSNotFound else { break }
            text.addAttribute(.kern, value: wordKern, range: space)
            searchRange = NSRange(location: NSMaxRange(space), length: nsString.length - NSMaxRange(space))
        }
        return text
    }

    static func attributes(settings: ReadingSettings) -> [NSAttributedString.Key: Any] {
        let font = font(settings: settings)
        let lineHeight = font.pointSize * CGFloat(settings.lineSpacingPercent) / 100
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .justified
        // Without it, a justified line with few words is stretched letter by letter on a narrow iPhone column.
        paragraphStyle.hyphenationFactor = 1
        paragraphStyle.minimumLineHeight = lineHeight
        paragraphStyle.maximumLineHeight = lineHeight
        paragraphStyle.paragraphSpacing = lineHeight
        return [
            .font: font,
            .paragraphStyle: paragraphStyle,
            .foregroundColor: textColor(for: settings.theme),
            .kern: characterKern(settings: settings)
        ]
    }

    private static func characterKern(settings: ReadingSettings) -> CGFloat {
        CGFloat(settings.textSize) * CGFloat(settings.characterSpacingPercent) / 100
    }

    private static func adaptive(light: UInt32, dark: UInt32) -> UIColor {
        UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) }
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
