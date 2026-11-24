import Foundation
import Observation

@MainActor
@Observable
final class ReaderSettingsVM {
    private(set) var settings = ReadingSettings()
    private(set) var layoutSettings = ReadingSettings()
    private(set) var brightness = 0.0

    @ObservationIgnored var onSettingsChanged: () -> Void = {}
    private let readerStateCtrl: ReaderStateCtrl

    init(readerStateCtrl: ReaderStateCtrl) {
        self.readerStateCtrl = readerStateCtrl
    }

    /// true: dark, false: light, nil: whatever the device uses.
    var isDarkMode: Bool? {
        settings.readingMode.isDark(screenBrightness: brightness)
    }

    /// Line spacing as a multiple of the text size, like "1.55".
    var lineSpacingLabel: String {
        (Double(settings.lineSpacingPercent) / 100).formatted(.number.precision(.fractionLength(2)))
    }

    var characterSpacingLabel: String {
        "\(settings.characterSpacingPercent)%"
    }

    var wordSpacingLabel: String {
        "\(settings.wordSpacingPercent)%"
    }

    // MARK: Values as the controls read and set them
    // Writable, so the view binds to them directly. Setting one goes through the same rules as the *Changed methods.

    static let textSizeSliderRange = 0...Double(ReadingSettings.textSizes.count - 1)
    static let lineSpacingSliderRange = doubles(ReadingSettings.lineSpacingPercents)
    static let characterSpacingSliderRange = doubles(ReadingSettings.characterSpacingPercents)
    static let wordSpacingSliderRange = doubles(ReadingSettings.wordSpacingPercents)

    var textSizeSlider: Double {
        get { Double(settings.textSizeIndex) }
        set { textSizeChanged(newValue) }
    }

    var brightnessSlider: Double {
        get { brightness }
        set { brightnessChanged(newValue) }
    }

    var lineSpacingSlider: Double {
        get { Double(settings.lineSpacingPercent) }
        set { lineSpacingChanged(newValue) }
    }

    var characterSpacingSlider: Double {
        get { Double(settings.characterSpacingPercent) }
        set { characterSpacingChanged(newValue) }
    }

    var wordSpacingSlider: Double {
        get { Double(settings.wordSpacingPercent) }
        set { wordSpacingChanged(newValue) }
    }

    var selectedPageTurnStyle: PageTurnStyle {
        get { settings.pageTurnStyle }
        set { pageTurnStyleChanged(newValue) }
    }

    var selectedReadingMode: ReadingMode {
        get { settings.readingMode }
        set { readingModeChanged(newValue) }
    }

    func bookOpened() async {
        settings = await readerStateCtrl.settings()
        brightness = await readerStateCtrl.brightness()
    }

    func layoutChanged(to settings: ReadingSettings) {
        layoutSettings = settings
    }

    func themeSettingsShown() {
        Task { brightness = await readerStateCtrl.brightness() }
    }

    /// The screen's brightness changed outside the slider: auto-brightness, or Control Center. Match Surroundings follows it.
    func screenBrightnessChanged() {
        Task { brightness = await readerStateCtrl.brightness() }
    }

    func textSizeChanged(_ value: Double) {
        let index = min(max(Int(value.rounded()), 0), ReadingSettings.textSizes.count - 1)
        changeSettings { $0.textSizeIndex = index }
    }

    func lineSpacingChanged(_ value: Double) {
        let percent = Self.stepped(value, in: ReadingSettings.lineSpacingPercents, step: ReadingSettings.lineSpacingPercentStep)
        changeSettings { $0.lineSpacingPercent = percent }
    }

    func characterSpacingChanged(_ value: Double) {
        let percent = Self.stepped(value, in: ReadingSettings.characterSpacingPercents, step: 1)
        changeSettings { $0.characterSpacingPercent = percent }
    }

    func wordSpacingChanged(_ value: Double) {
        let percent = Self.stepped(value, in: ReadingSettings.wordSpacingPercents, step: ReadingSettings.wordSpacingPercentStep)
        changeSettings { $0.wordSpacingPercent = percent }
    }

    func themeTapped(_ theme: ReadingTheme) {
        changeSettings { $0.theme = theme }
    }

    func pageTurnStyleChanged(_ style: PageTurnStyle) {
        changeSettings { $0.pageTurnStyle = style }
    }

    func readingModeChanged(_ mode: ReadingMode) {
        changeSettings { $0.readingMode = mode }
    }

    /// Back to the default text size, theme and spacing. The page turn and the reading mode are kept: they are chosen from
    /// their own menus.
    func resetTapped() {
        changeSettings {
            let defaults = ReadingSettings()
            $0.textSizeIndex = defaults.textSizeIndex
            $0.lineSpacingPercent = defaults.lineSpacingPercent
            $0.characterSpacingPercent = defaults.characterSpacingPercent
            $0.wordSpacingPercent = defaults.wordSpacingPercent
            $0.theme = defaults.theme
        }
    }

    func brightnessChanged(_ brightness: Double) {
        self.brightness = brightness
        Task { await readerStateCtrl.changeBrightness(to: brightness) }
    }

    private func changeSettings(_ change: (inout ReadingSettings) -> Void) {
        let previous = settings
        change(&settings)
        guard settings != previous else { return }
        let settings = settings
        Task { await readerStateCtrl.save(settings) }
        onSettingsChanged()
    }

    private static func doubles(_ range: ClosedRange<Int>) -> ClosedRange<Double> {
        Double(range.lowerBound)...Double(range.upperBound)
    }

    private static func stepped(_ value: Double, in range: ClosedRange<Int>, step: Int) -> Int {
        let rounded = Int((value / Double(step)).rounded()) * step
        return min(max(rounded, range.lowerBound), range.upperBound)
    }
}
