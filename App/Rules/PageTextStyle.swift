import UIKit

enum PageTextStyle {
    private static let maxTextWidth: CGFloat = 690
    private static let minSideMargin: CGFloat = 24

    static func attributes(settings: ReadingSettings, bodyFontSize: CGFloat) -> [NSAttributedString.Key: Any] {
        let textSizeScale = 1 + 0.1 * CGFloat(settings.textSizeStep)
        let font = UIFont.systemFont(ofSize: bodyFontSize * textSizeScale)
        let lineSpacingScale = 0.12 + 0.08 * CGFloat(settings.lineSpacingStep)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .justified
        paragraphStyle.lineSpacing = font.pointSize * lineSpacingScale
        paragraphStyle.paragraphSpacing = font.lineHeight + paragraphStyle.lineSpacing
        return [.font: font, .paragraphStyle: paragraphStyle, .foregroundColor: UIColor.label]
    }

    static func textFrame(in bounds: CGRect) -> CGRect {
        let width = min(maxTextWidth, bounds.width - 2 * minSideMargin)
        return CGRect(x: bounds.midX - width / 2, y: bounds.minY, width: width, height: bounds.height)
    }
}
