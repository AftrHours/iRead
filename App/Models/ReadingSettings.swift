import Foundation

struct ReadingSettings: Codable, Equatable, Sendable {
    static let textSizeSteps = -3...6
    static let lineSpacingSteps = 0...4
    static let themeCount = 5

    var textSizeStep = 0
    var lineSpacingStep = 0
    var themeIndex = 0
    var areSymbolsShown = false
}
