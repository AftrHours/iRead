import Foundation
import OSLog

actor ProgRepo {
    private let booksFolder = URL.applicationSupportDirectory.appending(path: "Books")
    private var pending: [UUID: ReadingProgress] = [:]
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let logger = Logger(subsystem: "com.AftrHours.iRead", category: "storage")

    init() {
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func progress(for bookID: UUID) -> ReadingProgress? {
        guard let data = try? Data(contentsOf: fileURL(for: bookID)) else { return nil }
        return try? decoder.decode(ReadingProgress.self, from: data)
    }

    func save(_ progress: ReadingProgress) {
        // Saves that arrive before this write runs replace each other, so only the latest one is written.
        if pending.isEmpty {
            Task { writePending() }
        }
        pending[progress.bookID] = progress
    }

    func saveNow(_ progress: ReadingProgress) {
        pending[progress.bookID] = progress
        writePending()
    }

    /// Keeps the reading position, so marking a finished book as still reading goes back to where the reader was.
    func setFinished(_ isFinished: Bool, for bookID: UUID) {
        let current = pending[bookID] ?? progress(for: bookID)
        saveNow(ReadingProgress(
            bookID: bookID,
            position: current?.position ?? ReadingPosition(paragraph: 0, charOffset: 0),
            chapterIndex: current?.chapterIndex ?? 0,
            progress: current?.progress ?? 0,
            lastReadAt: current?.lastReadAt ?? .now,
            readingFrontier: current?.readingFrontier ?? 0,
            finishedAt: isFinished ? .now : nil
        ))
    }

    /// Saved as a 0% record rather than deleted, so a sample book doesn't fall back to its mock progress.
    func resetProgress(for bookID: UUID) {
        let current = pending[bookID] ?? progress(for: bookID)
        saveNow(ReadingProgress(
            bookID: bookID,
            position: ReadingPosition(paragraph: 0, charOffset: 0),
            chapterIndex: 0,
            progress: 0,
            lastReadAt: current?.lastReadAt ?? .now,
            readingFrontier: 0,
            finishedAt: nil
        ))
    }

    private func writePending() {
        while let (bookID, progress) = pending.popFirst() {
            let url = fileURL(for: bookID)
            do {
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try encoder.encode(progress).write(to: url, options: .atomic)
            } catch {
                logger.error("Couldn't save progress for \(bookID.uuidString, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func fileURL(for bookID: UUID) -> URL {
        booksFolder.appending(path: "\(bookID.uuidString)/progress.json")
    }
}
