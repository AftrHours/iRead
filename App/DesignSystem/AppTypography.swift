import CoreText
import SwiftUI
import UIKit

/// DM Sans styles mapped to Apple's semantic text styles for Dynamic Type support.
enum AppTypography {
    static func largeTitle(_ weight: Font.Weight = .bold) -> Font { font(size: 34, relativeTo: .largeTitle, weight: weight) }
    static func title1(_ weight: Font.Weight = .bold) -> Font { font(size: 28, relativeTo: .title1, weight: weight) }
    static func title2(_ weight: Font.Weight = .bold) -> Font { font(size: 22, relativeTo: .title2, weight: weight) }
    static func title3(_ weight: Font.Weight = .semibold) -> Font { font(size: 20, relativeTo: .title3, weight: weight) }
    static func headline(_ weight: Font.Weight = .bold) -> Font { font(size: 17, relativeTo: .headline, weight: weight) }
    static func body(_ weight: Font.Weight = .regular) -> Font { font(size: 17, relativeTo: .body, weight: weight) }
    static func callout(_ weight: Font.Weight = .regular) -> Font { font(size: 16, relativeTo: .callout, weight: weight) }
    static func subheadline(_ weight: Font.Weight = .regular) -> Font { font(size: 15, relativeTo: .subheadline, weight: weight) }
    static func footnote(_ weight: Font.Weight = .regular) -> Font { font(size: 13, relativeTo: .footnote, weight: weight) }
    static func caption1(_ weight: Font.Weight = .regular) -> Font { font(size: 12, relativeTo: .caption1, weight: weight) }
    static func caption2(_ weight: Font.Weight = .regular) -> Font { font(size: 11, relativeTo: .caption2, weight: weight) }

    private static func font(size: CGFloat, relativeTo style: UIFont.TextStyle, weight: Font.Weight) -> Font {
        _ = registerFont
        return .custom("DMSans-9ptRegular", size: size, relativeTo: Font.TextStyle(style)).weight(weight)
    }

    private static let registerFont: Bool = {
        guard let url = Bundle.main.url(forResource: "DMSansVariable", withExtension: "ttf") else { return false }
        var error: Unmanaged<CFError>?
        let registered = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        return registered || error == nil
    }()
}

private extension Font.TextStyle {
    init(_ style: UIFont.TextStyle) {
        switch style {
        case .largeTitle: self = .largeTitle
        case .title1: self = .title
        case .title2: self = .title2
        case .title3: self = .title3
        case .headline: self = .headline
        case .body: self = .body
        case .callout: self = .callout
        case .subheadline: self = .subheadline
        case .footnote: self = .footnote
        case .caption1: self = .caption
        default: self = .caption2
        }
    }
}
