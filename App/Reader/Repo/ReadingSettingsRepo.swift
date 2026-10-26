import Foundation
import OSLog

struct ReadingSettingsRepo {
    private let fileURL = URL.applicationSupportDirectory.appending(path: "reading-settings.json")
    private let logger = Logger(subsystem: "com.AftrHours.iRead", category: "storage")

    func settings() async -> ReadingSettings {
        guard let data = try? Data(contentsOf: fileURL),
              let settings = try? JSONDecoder().decode(ReadingSettings.self, from: data) else {
            return ReadingSettings()
        }
        return settings
    }

    func save(_ settings: ReadingSettings) async {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(settings).write(to: fileURL, options: .atomic)
        } catch {
            logger.error("Couldn't save reading settings: \(error.localizedDescription, privacy: .public)")
        }
    }
}
