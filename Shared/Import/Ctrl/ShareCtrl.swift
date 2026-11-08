import Foundation

enum ShareOutcome: Equatable, Sendable {
    /// Found and downloaded: Send can hand `file` to the app.
    case found(GutenbergEdition, file: URL)
    case unsupportedLink
    /// `title` is the Apple Books title, when the listing was found.
    case notFound(title: String?)
    case alreadyInLibrary(title: String)
    case unreachable
    case tooLarge
}

enum ShareCtrlKnobs {
    /// For the whole search and download, so the sheet never spins for long.
    static let timeout: Duration = .seconds(30)
    static let maxBytes = 100_000_000
}

/// The Share extension's one job: from an Apple Books link to a downloaded Project Gutenberg EPUB, then hand it to the app.
/// Four dependencies (one over the usual three): looking up, downloading and handing off are one use case.
struct ShareCtrl: Sendable {
    private let bookLookupSvc: any BookLookupSvc
    private let downloadSvc: any DownloadSvc
    private let libraryIndexRepo: LibraryIndexRepo
    private let pendingImportRepo: PendingImportRepo
    private let timeout: Duration

    init(bookLookupSvc: any BookLookupSvc, downloadSvc: any DownloadSvc, libraryIndexRepo: LibraryIndexRepo,
         pendingImportRepo: PendingImportRepo, timeout: Duration = ShareCtrlKnobs.timeout) {
        self.bookLookupSvc = bookLookupSvc
        self.downloadSvc = downloadSvc
        self.libraryIndexRepo = libraryIndexRepo
        self.pendingImportRepo = pendingImportRepo
        self.timeout = timeout
    }

    func resolve(_ link: URL) async -> ShareOutcome {
        await withTaskGroup(of: ShareOutcome?.self) { group in
            group.addTask { await self.find(link) }
            group.addTask {
                try? await Task.sleep(for: self.timeout)
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first ?? .unreachable
        }
    }

    func send(_ edition: GutenbergEdition, file: URL) throws {
        try pendingImportRepo.add(epubAt: file, edition: edition)
    }

    /// Title and last name first. Gutenberg's search already matched the author there (it knows "Sun Tzu" is "Sunzi"), so
    /// only the title is checked. When that finds nothing, the title alone, where the author is checked too.
    private func edition(for listing: (title: String, author: String)) async throws -> GutenbergEdition? {
        let query = EditionMatcher.searchQuery(title: listing.title, author: listing.author)
        let match = EditionMatcher.bestMatch(title: listing.title, author: "",
                                             in: try await bookLookupSvc.gutenbergBooks(matching: query))
        let titleOnly = EditionMatcher.titleQuery(listing.title)
        guard match == nil, titleOnly != query else { return match.map { named($0, by: listing.author) } }
        return EditionMatcher.bestMatch(title: listing.title, author: listing.author,
                                        in: try await bookLookupSvc.gutenbergBooks(matching: titleOnly))
            .map { named($0, by: listing.author) }
    }

    /// Apple's author name: Gutenberg's can read "active 6th century B.C. Sunzi".
    private func named(_ edition: GutenbergEdition, by author: String) -> GutenbergEdition {
        guard !author.isEmpty else { return edition }
        return GutenbergEdition(number: edition.number, title: edition.title, author: author, epubURL: edition.epubURL)
    }

    private func find(_ link: URL) async -> ShareOutcome {
        guard let (id, country) = AppleBooksLink.listing(in: link) else { return .unsupportedLink }
        let listing: (title: String, author: String)?
        let match: GutenbergEdition?
        do {
            listing = try await bookLookupSvc.listing(id: id, country: country)
            guard let listing else { return .notFound(title: nil) }
            match = try await edition(for: listing)
        } catch {
            return .unreachable
        }
        guard let edition = match else { return .notFound(title: listing?.title) }
        let identity = BookIdentity(gutenbergNumber: edition.number, title: edition.title, author: edition.author, fingerprint: nil)
        if let existing = DuplicateRules.match(identity, in: libraryIndexRepo.load().books) {
            return .alreadyInLibrary(title: existing.title)
        }
        do {
            return .found(edition, file: try await downloadSvc.download(edition.epubURL, maxBytes: ShareCtrlKnobs.maxBytes))
        } catch ImportError.tooLarge {
            return .tooLarge
        } catch {
            return .unreachable
        }
    }
}
