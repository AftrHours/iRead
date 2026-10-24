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

    func textSizeDecreased() {
        changeSettings { $0.textSizeStep = max($0.textSizeStep - 1, ReadingSettings.textSizeSteps.lowerBound) }
    }

    func textSizeIncreased() {
        changeSettings { $0.textSizeStep = min($0.textSizeStep + 1, ReadingSettings.textSizeSteps.upperBound) }
    }

    func lineSpacingDecreased() {
        changeSettings { $0.lineSpacingStep = max($0.lineSpacingStep - 1, ReadingSettings.lineSpacingSteps.lowerBound) }
    }

    func lineSpacingIncreased() {
        changeSettings { $0.lineSpacingStep = min($0.lineSpacingStep + 1, ReadingSettings.lineSpacingSteps.upperBound) }
    }

    func themeTapped(_ index: Int) {
        changeSettings { $0.themeIndex = index }
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
        if settings != previous {
            let settings = settings
            Task { await readerStateCtrl.save(settings) }
        }
        onSettingsChanged()
    }
}
