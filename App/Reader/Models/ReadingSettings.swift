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

    /// Its SF Symbol in the Reading Animation menu.
    var systemImage: String {
        switch self {
        case .slide: "rectangle.righthalf.inset.filled"
        case .curl: "doc"
        case .fastFade: "bolt.square"
        }
    }
}

/// Whether the page and the reader's controls are light or dark.
enum ReadingMode: String, Codable, CaseIterable, Sendable, Identifiable {
    case light
    case dark
    case matchDevice
    /// iOS gives apps no ambient light reading, so the screen's brightness stands in for it: with auto-brightness on,
    /// it follows the room.
    case matchSurroundings

    var id: Self { self }

    /// Below this screen brightness, Match Surroundings turns dark.
    static let darkSurroundingsBrightness = 0.3

    var title: String {
        switch self {
        case .light: "Light"
        case .dark: "Dark"
        case .matchDevice: "Match Device"
        case .matchSurroundings: "Match Surroundings"
        }
    }

    /// Its SF Symbol in the Reading Mode menu.
    var systemImage: String {
        switch self {
        case .light: "sun.horizon"
        case .dark: "moon.stars"
        case .matchDevice: "circle.lefthalf.filled"
        case .matchSurroundings: "sun.lefthalf.filled"
        }
    }

    /// true: dark, false: light, nil: whatever the device uses.
    func isDark(screenBrightness: Double) -> Bool? {
        switch self {
        case .light: false
        case .dark: true
        case .matchDevice: nil
        case .matchSurroundings: screenBrightness < Self.darkSurroundingsBrightness
        }
    }
}

struct ReadingSettings: Codable, Equatable, Sendable {
    /// Apple Books' iPad body sizes, smallest to largest.
    static let textSizes: [Double] = [17, 18, 19, 20, 23, 25, 28, 34, 40, 48, 56]
    /// Line height as a percent of the text size, changed 5 at a time.
    static let lineSpacingPercents = 80...250
    static let lineSpacingPercentStep = 5
    /// Extra space between letters, as a percent of the text size.
    static let characterSpacingPercents = 0...10
    /// Extra space between words, as a percent of a space's width, changed 5 at a time.
    static let wordSpacingPercents = 0...100
    static let wordSpacingPercentStep = 5

    var textSizeIndex = 3
    var lineSpacingPercent = 120
    var characterSpacingPercent = 0
    var wordSpacingPercent = 0
    var theme = ReadingTheme.original
    var pageTurnStyle = PageTurnStyle.slide
    var readingMode = ReadingMode.matchDevice

    private enum CodingKeys: String, CodingKey {
        case textSizeIndex, lineSpacingPercent, characterSpacingPercent, wordSpacingPercent, theme, pageTurnStyle, readingMode
    }

    init() {}

    /// A file saved by an older build keeps its settings; anything it doesn't have gets its default.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = ReadingSettings()
        textSizeIndex = try container.decodeIfPresent(Int.self, forKey: .textSizeIndex) ?? defaults.textSizeIndex
        lineSpacingPercent = try container.decodeIfPresent(Int.self, forKey: .lineSpacingPercent) ?? defaults.lineSpacingPercent
        characterSpacingPercent = try container.decodeIfPresent(Int.self, forKey: .characterSpacingPercent)
            ?? defaults.characterSpacingPercent
        wordSpacingPercent = try container.decodeIfPresent(Int.self, forKey: .wordSpacingPercent) ?? defaults.wordSpacingPercent
        theme = try container.decodeIfPresent(ReadingTheme.self, forKey: .theme) ?? defaults.theme
        pageTurnStyle = try container.decodeIfPresent(PageTurnStyle.self, forKey: .pageTurnStyle) ?? defaults.pageTurnStyle
        readingMode = try container.decodeIfPresent(ReadingMode.self, forKey: .readingMode) ?? defaults.readingMode
    }

    var textSize: Double {
        Self.textSizes[min(max(textSizeIndex, 0), Self.textSizes.count - 1)]
    }
}
