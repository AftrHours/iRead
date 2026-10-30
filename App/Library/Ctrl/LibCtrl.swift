import Foundation

struct LibCtrl {
    let libRepo: LibRepo
    let bookContentRepo: BookContentRepo

    func loadLibrary() async throws -> [BookRecord] {
        return try await libRepo.fetchBooks()
    }

    func importBook(from url: URL) async throws -> BookRecord {
        try await libRepo.importBook(from: url)
    }

    func cover(for bookID: UUID) async -> Data? {
        await bookContentRepo.cover(for: bookID)
    }

    func setFinished(_ isFinished: Bool, for book: BookRecord) async {
        await libRepo.setFinished(isFinished, for: book)
    }

    func resetProgress(for book: BookRecord) async {
        await libRepo.resetProgress(for: book)
    }

    func remove(_ book: BookRecord) throws {
        try libRepo.remove(book)
    }

    func shareableFile(for book: BookRecord) async throws -> URL {
        try await bookContentRepo.shareableFile(for: book)
    }
}
