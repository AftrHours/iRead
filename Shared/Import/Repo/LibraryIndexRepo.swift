import Foundation
import OSLog

/// `library-index.json` in the App Group: the app writes it, the Share extension reads it.
struct LibraryIndexRepo: Sendable {
    private let fileURL: URL
    private let logger = Logger(subsystem: Logger.appSubsystem, category: "storage")

    init(folder: URL = AppGroup.folder) {
        fileURL = folder.appending(path: "library-index.json")
    }

    /// Empty when the app hasn't written one yet.
    func readIndex() -> LibraryIndex {
        guard let data = try? Data(contentsOf: fileURL),
              let index = try? JSONDecoder().decode(LibraryIndex.self, from: data) else { return LibraryIndex(books: []) }
        return index
    }

    func writeIndex(_ index: LibraryIndex) {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(index).write(to: fileURL, options: .atomic)
        } catch {
            logger.error("Couldn't save the library index: \(error.localizedDescription, privacy: .public)")
        }
    }
}
