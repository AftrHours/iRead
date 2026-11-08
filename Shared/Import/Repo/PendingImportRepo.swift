import Foundation
import OSLog

/// A book the Share extension found and downloaded, waiting for the app to import it.
struct PendingImport: Sendable, Equatable {
    let id: UUID
    let epubURL: URL
    let edition: GutenbergEdition
}

/// Shared books waiting in the App Group: `<folder>/<id>/book.epub` and `<folder>/<id>/edition.json`.
struct PendingImportRepo: Sendable {
    private let folder: URL
    private let logger = Logger(subsystem: Logger.appSubsystem, category: "storage")

    init(folder: URL = AppGroup.folder.appending(path: "PendingImports")) {
        self.folder = folder
    }

    /// Moves the downloaded file in. The edition is written last, so a half-written import is never listed.
    func add(epubAt file: URL, edition: GutenbergEdition) throws {
        let entry = folder.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: entry, withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: file, to: entry.appending(path: "book.epub"))
        try JSONEncoder().encode(edition).write(to: entry.appending(path: "edition.json"), options: .atomic)
    }

    func all() -> [PendingImport] {
        let entries = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        return entries.compactMap { entry in
            let epubURL = entry.appending(path: "book.epub")
            guard let id = UUID(uuidString: entry.lastPathComponent),
                  FileManager.default.fileExists(atPath: epubURL.path),
                  let data = try? Data(contentsOf: entry.appending(path: "edition.json")),
                  let edition = try? JSONDecoder().decode(GutenbergEdition.self, from: data) else { return nil }
            return PendingImport(id: id, epubURL: epubURL, edition: edition)
        }
    }

    func remove(_ pending: PendingImport) {
        do {
            try FileManager.default.removeItem(at: folder.appending(path: pending.id.uuidString))
        } catch {
            logger.error("Couldn't remove pending import \(pending.id, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }
}
