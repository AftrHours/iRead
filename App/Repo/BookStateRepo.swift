import Foundation

struct BookStateRepo {
    private let booksFolder = URL.applicationSupportDirectory.appending(path: "Books")

    func state(for bookID: UUID) async -> BookState {
        guard let data = try? Data(contentsOf: fileURL(for: bookID)),
              let state = try? JSONDecoder().decode(BookState.self, from: data) else {
            return BookState()
        }
        return state
    }

    func save(_ state: BookState, for bookID: UUID) async {
        let url = fileURL(for: bookID)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? JSONEncoder().encode(state).write(to: url, options: .atomic)
    }

    private func fileURL(for bookID: UUID) -> URL {
        booksFolder.appending(path: "\(bookID.uuidString)/state.json")
    }
}
