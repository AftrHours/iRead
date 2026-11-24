import Foundation
import Testing
@testable import iRead

@Suite("ReadingSettings")
struct ReadingSettingsTests {
    private let folder = TempFolder()

    @Test("RD-21 an out-of-range text size index uses the nearest size")
    func textSizeClamped() {
        var settings = ReadingSettings()
        settings.textSizeIndex = -1
        #expect(settings.textSize == 17)
        settings.textSizeIndex = 99
        #expect(settings.textSize == 56)
    }

    @Test("RD-44 a page is dark in the dark reading mode, and Quiet's page is dark in any")
    func darkPage() {
        #expect(!ReadingTheme.original.isDarkPage(isDarkMode: false))
        #expect(ReadingTheme.original.isDarkPage(isDarkMode: true))
        #expect(ReadingTheme.quiet.isDarkPage(isDarkMode: false))
        #expect(ReadingTheme.paper.isDarkPage(isDarkMode: true))
    }

    @Test("RD-22 ReadingSettingsRepo gives defaults with no file, then what was saved")
    func repo() async {
        let repo = ReadingSettingsRepo(folder: folder.url)
        #expect(await repo.settings() == ReadingSettings())
        var settings = ReadingSettings()
        settings.textSizeIndex = 6
        settings.lineSpacingPercent = 150
        settings.theme = .calm
        await repo.save(settings)
        #expect(await ReadingSettingsRepo(folder: folder.url).settings() == settings)
    }
}
