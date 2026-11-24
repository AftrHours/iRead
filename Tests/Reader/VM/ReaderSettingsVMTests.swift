import Foundation
import Testing
import UIKit
@testable import iRead

@MainActor
@Suite("Reading Theme & Settings")
struct ReaderSettingsVMTests {
    private let folder = TempFolder()

    private func makeVM() -> ReaderSettingsVM {
        let readerStateCtrl = ReaderStateCtrl(bookID: UUID(), readingSettingsRepo: ReadingSettingsRepo(folder: folder.url),
                                              brightnessSvc: BrightnessSvc(), bookStateRepo: BookStateRepo(folder: folder.url))
        return ReaderSettingsVM(readerStateCtrl: readerStateCtrl)
    }

    @Test("RD-31 the spacing sliders snap to their steps and stay in range; labels read like the design")
    func spacingSliders() {
        let vm = makeVM()
        vm.lineSpacingChanged(156.9)
        vm.characterSpacingChanged(42)
        vm.wordSpacingChanged(12.6)
        #expect(vm.settings.lineSpacingPercent == 155)
        #expect(vm.settings.characterSpacingPercent == 10)
        #expect(vm.settings.wordSpacingPercent == 15)
        #expect(vm.lineSpacingLabel == (1.55).formatted(.number.precision(.fractionLength(2))))
        #expect(vm.wordSpacingLabel == "15%")
        vm.lineSpacingChanged(10)
        #expect(vm.settings.lineSpacingPercent == ReadingSettings.lineSpacingPercents.lowerBound)
    }

    @Test("RD-32 Reset to Default restores size, theme and spacing, and keeps the page turn and reading mode")
    func reset() {
        let vm = makeVM()
        vm.textSizeChanged(8)
        vm.themeTapped(.calm)
        vm.lineSpacingChanged(200)
        vm.characterSpacingChanged(5)
        vm.wordSpacingChanged(50)
        vm.pageTurnStyleChanged(.curl)
        vm.readingModeChanged(.dark)

        vm.resetTapped()

        var expected = ReadingSettings()
        expected.pageTurnStyle = .curl
        expected.readingMode = .dark
        #expect(vm.settings == expected)
    }

    @Test("RD-33 reading mode: light and dark are fixed, Match Device leaves it to iOS, Match Surroundings follows the screen")
    func readingMode() {
        #expect(ReadingMode.light.isDark(screenBrightness: 0) == false)
        #expect(ReadingMode.dark.isDark(screenBrightness: 1) == true)
        #expect(ReadingMode.matchDevice.isDark(screenBrightness: 0) == nil)
        #expect(ReadingMode.matchSurroundings.isDark(screenBrightness: 0.1) == true)
        #expect(ReadingMode.matchSurroundings.isDark(screenBrightness: 0.8) == false)
    }

    @Test("RD-34 a settings file from an older build keeps its values; the new settings get their defaults")
    func olderFile() throws {
        let json = #"{"textSizeIndex":6,"lineSpacingPercent":150,"theme":"calm","pageTurnStyle":"curl"}"#
        let settings = try JSONDecoder().decode(ReadingSettings.self, from: Data(json.utf8))
        #expect(settings.textSizeIndex == 6)
        #expect(settings.theme == .calm)
        #expect(settings.characterSpacingPercent == 0)
        #expect(settings.wordSpacingPercent == 0)
        #expect(settings.readingMode == .matchDevice)
    }

    @Test("RD-35 character spacing kerns every letter; word spacing adds more to the spaces only")
    func spacingInText() throws {
        var settings = ReadingSettings()
        settings.characterSpacingPercent = 5
        settings.wordSpacingPercent = 50
        let text = PageTextStyle.attributedText("ab cd", settings: settings)
        let letterKern = try #require(text.attribute(.kern, at: 0, effectiveRange: nil) as? CGFloat)
        let spaceKern = try #require(text.attribute(.kern, at: 2, effectiveRange: nil) as? CGFloat)
        #expect(letterKern == CGFloat(settings.textSize) * 0.05)
        #expect(spaceKern > letterKern)
        #expect(text.attribute(.kern, at: 3, effectiveRange: nil) as? CGFloat == letterKern)

        let plain = PageTextStyle.attributedText("ab cd", settings: ReadingSettings())
        #expect(plain.attribute(.kern, at: 2, effectiveRange: nil) as? CGFloat == 0)
    }
}
