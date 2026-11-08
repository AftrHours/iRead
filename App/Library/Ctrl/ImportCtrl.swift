import Foundation
import OSLog

/// Adds books from outside the app (the picker, "Open in iRead", the Share extension), keeping the same book out twice,
/// and writes the library index the Share extension checks.
struct ImportCtrl {
    let libRepo: LibRepo
    let pendingImportRepo: PendingImportRepo
    let libraryIndexRepo: LibraryIndexRepo
    private let logger = Logger(subsystem: Logger.appSubsystem, category: "storage")

    init(libRepo: LibRepo, pendingImportRepo: PendingImportRepo, libraryIndexRepo: LibraryIndexRepo) {
        self.libRepo = libRepo
        self.pendingImportRepo = pendingImportRepo
        self.libraryIndexRepo = libraryIndexRepo
    }

    /// Throws `ImportError.alreadyInLibrary` for a book the reader can already see. A removed sample is shown again
    /// instead of copied. The copy iOS puts in Documents/Inbox is deleted either way.
    func importFile(from url: URL) async throws -> BookRecord {
        defer {
            if url.path.contains("/Documents/Inbox/") { try? FileManager.default.removeItem(at: url) }
        }
        let candidate = try await libRepo.candidate(for: url)
        if let existing = DuplicateRules.match(candidate.identity, in: try libRepo.fetchBooks().map(Self.indexed)) {
            throw ImportError.alreadyInLibrary(title: existing.title)
        }
        if let sample = libRepo.hiddenSamples().first(where: { DuplicateRules.match(candidate.identity, in: [Self.indexed($0)]) != nil }) {
            try libRepo.unhideSample(sample.id)
            return sample
        }
        return try libRepo.importBook(from: url, as: candidate)
    }

    /// Books the Share extension left. A duplicate or unreadable one is logged and dropped: the reader already left the sheet.
    func importPending() async -> [BookRecord] {
        var added: [BookRecord] = []
        for pending in pendingImportRepo.all() {
            do {
                added.append(try await importFile(from: pending.epubURL))
            } catch {
                logger.info("Dropped shared book \(pending.edition.number, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
            pendingImportRepo.remove(pending)
        }
        return added
    }

    func refreshIndex() throws {
        libraryIndexRepo.save(LibraryIndex(books: try libRepo.fetchBooks().map(Self.indexed)))
    }

    private static func indexed(_ book: BookRecord) -> IndexedBook {
        IndexedBook(title: book.title, identity: book.identity)
    }
}
