import Foundation

struct ReadingSettingsRepo {
    private let fileURL = URL.applicationSupportDirectory.appending(path: "reading-settings.json")

    func settings() async -> ReadingSettings {
        guard let data = try? Data(contentsOf: fileURL),
              let settings = try? JSONDecoder().decode(ReadingSettings.self, from: data) else {
            return ReadingSettings()
        }
        return settings
    }

    func save(_ settings: ReadingSettings) async {
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? JSONEncoder().encode(settings).write(to: fileURL, options: .atomic)
    }
}
