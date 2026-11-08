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
    func importBook(from url: URL) async throws -> BookRecord {
        defer {
            if url.path.contains("/Documents/Inbox/") { try? FileManager.default.removeItem(at: url) }
        }
        let candidate = try await libRepo.readEPUB(at: url)
        if let existing = DuplicateRules.checkDuplicates(of: candidate.identity, in: try libRepo.fetchBooks().map(Self.summarize)) {
            throw ImportError.alreadyInLibrary(title: existing.title)
        }
        if let sample = libRepo.hiddenSamples().first(where: { DuplicateRules.checkDuplicates(of: candidate.identity, in: [Self.summarize($0)]) != nil }) {
            try libRepo.showHiddenSample(sample.id)
            return sample
        }
        return try libRepo.saveBook(from: url, as: candidate)
    }

    /// Books the Share extension left. A duplicate or unreadable one is logged and dropped: the reader already left the sheet.
    func importPending() async -> [BookRecord] {
        var added: [BookRecord] = []
        for pending in pendingImportRepo.readPending() {
            do {
                added.append(try await importBook(from: pending.epubURL))
            } catch {
                logger.info("Dropped shared book \(pending.edition.number, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
            pendingImportRepo.removePending(pending)
        }
        return added
    }

    func refreshIndex() throws {
        libraryIndexRepo.writeIndex(LibraryIndex(books: try libRepo.fetchBooks().map(Self.summarize)))
    }

    private static func summarize(_ book: BookRecord) -> IndexedBook {
        IndexedBook(title: book.title, identity: book.identity)
    }
}
