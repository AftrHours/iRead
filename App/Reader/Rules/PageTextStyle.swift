import UIKit

enum PageTextStyle {
    private static let maxTextWidth: CGFloat = 690
    private static let minSideMargin: CGFloat = 24

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

    static func textColor(for theme: ReadingTheme) -> UIColor {
        switch theme {
        case .original: .label
        case .quiet: UIColor(hex: 0x8E8E90)
        case .paper, .bold: UIColor(hex: 0x1C1C1E)
        case .calm: UIColor(hex: 0x413524)
        case .focus: UIColor(hex: 0x1A1A1A)
        }
    }

    static func backgroundColor(for theme: ReadingTheme) -> UIColor {
        switch theme {
        case .original: .systemBackground
        case .quiet: UIColor(hex: 0x4A4A4C)
        case .paper, .bold: UIColor(hex: 0xEDEDED)
        case .calm: UIColor(hex: 0xF1E4CA)
        case .focus: UIColor(hex: 0xFFFCF1)
        }
    }

    static func attributes(settings: ReadingSettings) -> [NSAttributedString.Key: Any] {
        let font = font(settings: settings)
        let lineHeight = font.pointSize * CGFloat(settings.lineSpacingPercent) / 100
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .justified
        paragraphStyle.minimumLineHeight = lineHeight
        paragraphStyle.maximumLineHeight = lineHeight
        paragraphStyle.paragraphSpacing = lineHeight
        return [.font: font, .paragraphStyle: paragraphStyle, .foregroundColor: textColor(for: settings.theme)]
    }

    static func textFrame(in bounds: CGRect) -> CGRect {
        let width = min(maxTextWidth, bounds.width - 2 * minSideMargin)
        return CGRect(x: bounds.midX - width / 2, y: bounds.minY, width: width, height: bounds.height)
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
