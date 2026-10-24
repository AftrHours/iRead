import Foundation
import OSLog

struct BookStateRepo {
    private let booksFolder = URL.applicationSupportDirectory.appending(path: "Books")
    private let logger = Logger(subsystem: "com.AftrHours.iRead", category: "storage")

    func state(for bookID: UUID) async -> BookState {
        guard let data = try? Data(contentsOf: fileURL(for: bookID)),
              let state = try? JSONDecoder().decode(BookState.self, from: data) else {
            return BookState()
        }
        return state
    }

    func save(_ state: BookState, for bookID: UUID) async {
        let url = fileURL(for: bookID)
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(state).write(to: url, options: .atomic)
        } catch {
            logger.error("Couldn't save book state for \(bookID.uuidString, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    private func fileURL(for bookID: UUID) -> URL {
        booksFolder.appending(path: "\(bookID.uuidString)/state.json")
    }
}
