import Foundation
import OSLog

struct ReadingSettingsRepo {
    private let fileURL: URL
    private let logger = Logger(subsystem: Logger.appSubsystem, category: "storage")

    init(folder: URL = .applicationSupportDirectory) {
        fileURL = folder.appending(path: "reading-settings.json")
    }

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
