import Foundation

struct LibCtrl {
    let libRepo: LibRepo
    let bookContentRepo: BookContentRepo
    let progRepo: ProgRepo

    /// Every book in the library, with its saved reading progress.
    func loadLibrary() async throws -> [BookRecord] {
        var books: [BookRecord] = []
        for book in try libRepo.fetchBooks() {
            books.append(withProgress(book, await progRepo.progress(for: book.id)))
        }
        return books
    }

    func cover(for bookID: UUID) async -> Data? {
        await bookContentRepo.cover(for: bookID)
    }

    func setFinished(_ isFinished: Bool, for book: BookRecord) async {
        await progRepo.setFinished(isFinished, for: book.id)
    }

    func resetProgress(for book: BookRecord) async {
        await progRepo.resetProgress(for: book.id)
    }

    func remove(_ book: BookRecord) async throws {
        try libRepo.remove(book)
        await bookContentRepo.forget(book.id)
    }

    func rename(_ book: BookRecord, to title: String) throws {
        try libRepo.rename(book, to: title)
    }

    /// A book with no saved progress keeps its own (a sample's mock progress, or 0 for an imported book).
    private func withProgress(_ book: BookRecord, _ progress: ReadingProgress?) -> BookRecord {
        guard let progress else { return book }
        return BookRecord(
            id: book.id,
            title: book.title,
            author: book.author,
            isContinueReading: book.isContinueReading,
            // A finished book shows as fully read, even if it was marked finished part way through.
            progress: progress.finishedAt == nil ? progress.progress : 1,
            dateAdded: book.dateAdded,
            lastReadAt: progress.lastReadAt,
            gutenbergNumber: book.gutenbergNumber,
            fingerprint: book.fingerprint
        )
    }
}
