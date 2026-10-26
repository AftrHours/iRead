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

    func bookOpened() async {
        settings = await readerStateCtrl.settings()
    }

    func layoutChanged(to settings: ReadingSettings) {
        layoutSettings = settings
    }

    func themeSettingsShown() {
        Task { brightness = await readerStateCtrl.brightness() }
    }

    func textSizeChanged(_ value: Double) {
        let index = min(max(Int(value.rounded()), 0), ReadingSettings.textSizes.count - 1)
        changeSettings { $0.textSizeIndex = index }
    }

    func lineSpacingDecreased() {
        changeSettings {
            $0.lineSpacingPercent = max($0.lineSpacingPercent - ReadingSettings.lineSpacingPercentStep, ReadingSettings.lineSpacingPercents.lowerBound)
        }
    }

    func lineSpacingIncreased() {
        changeSettings {
            $0.lineSpacingPercent = min($0.lineSpacingPercent + ReadingSettings.lineSpacingPercentStep, ReadingSettings.lineSpacingPercents.upperBound)
        }
    }

    func themeTapped(_ theme: ReadingTheme) {
        changeSettings { $0.theme = theme }
    }

    func symbolsToggled(_ isOn: Bool) {
        changeSettings { $0.areSymbolsShown = isOn }
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
}
