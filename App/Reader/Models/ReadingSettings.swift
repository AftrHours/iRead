import Foundation

enum ReadingTheme: String, Codable, CaseIterable, Sendable {
    case original, quiet, paper, bold, calm, focus

    var title: String {
        rawValue.capitalized
    }
}

enum PageTurnStyle: String, Codable, CaseIterable, Sendable, Identifiable {
    case slide
    case curl
    case fastFade

    var id: Self { self }

    var title: String {
        switch self {
        case .slide: "Slide"
        case .curl: "Curl"
        case .fastFade: "Fast Fade"
        }
    }
}

struct ReadingSettings: Codable, Equatable, Sendable {
    /// Apple Books' iPad body sizes, smallest to largest.
    static let textSizes: [Double] = [17, 18, 19, 20, 23, 25, 28, 34, 40, 48, 56]
    /// Line height as a percent of the text size, changed 5 at a time.
    static let lineSpacingPercents = 80...250
    static let lineSpacingPercentStep = 5

    var textSizeIndex = 3
    var lineSpacingPercent = 120
    var theme = ReadingTheme.original
    var areSymbolsShown = false
    var pageTurnStyle = PageTurnStyle.slide

    private enum CodingKeys: String, CodingKey {
        case textSizeIndex, lineSpacingPercent, theme, areSymbolsShown, pageTurnStyle
    }

    init() {}

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        textSizeIndex = try container.decodeIfPresent(Int.self, forKey: .textSizeIndex) ?? 3
        lineSpacingPercent = try container.decodeIfPresent(Int.self, forKey: .lineSpacingPercent) ?? 120
        theme = try container.decodeIfPresent(ReadingTheme.self, forKey: .theme) ?? .original
        areSymbolsShown = try container.decodeIfPresent(Bool.self, forKey: .areSymbolsShown) ?? false
        pageTurnStyle = try container.decodeIfPresent(PageTurnStyle.self, forKey: .pageTurnStyle) ?? .slide
    }

    var textSize: Double {
        Self.textSizes[min(max(textSizeIndex, 0), Self.textSizes.count - 1)]
    }

    /// Everything except the symbols toggle changes where pages break.
    func hasSameLayout(as other: ReadingSettings) -> Bool {
        textSizeIndex == other.textSizeIndex && lineSpacingPercent == other.lineSpacingPercent && theme == other.theme
    }
}
