import Observation
import UIKit

@MainActor
@Observable
final class LibVM {
    enum ViewMode: Hashable {
        case grid
        case list
    }
    var searchText = ""
    private(set) var isSearchActive = false
    var isImportPickerPresented = false
    private(set) var isSelectionMode = false
    private(set) var selectedBookIDs: Set<UUID> = []
    private(set) var isVoiceSearchActive = false
    private(set) var voiceSearchError: String?
    var renameDraft = ""
    private(set) var allBooks: [BookRecord] = []
    private(set) var viewMode = ViewMode.grid
    private(set) var sortOption = LibrarySortOption.latestRead
    private(set) var importError: String?
    private(set) var covers: [UUID: UIImage] = [:]
    private(set) var bookToRemove: BookRecord?
    private(set) var bookToRename: BookRecord?
    private(set) var bookActionError: String?
    private(set) var cloudAccount: CloudAccount = .unknown
    private var newestImportedBookID: UUID?
    private var lastImport: Task<Void, Never>?

    var books: [BookRecord] {
        LibrarySorter.sorted(allBooks, by: sortOption, pinning: newestImportedBookID)
    }

    var visibleBooks: [BookRecord] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return books }
        return books.filter {
            $0.title.localizedCaseInsensitiveContains(query)
                || $0.author.localizedCaseInsensitiveContains(query)
        }
    }

    var emptyStateTitle: String {
        if allBooks.isEmpty { return "Let’s add your first book!" }
        return searchText.isEmpty ? "No books found" : "No Results"
    }

    var emptyStateMessage: String {
        if allBooks.isEmpty { return "Tap the + button to import an EPUB file." }
        return "Try searching by title or author again."
    }

    var isImportAlertPresented: Bool {
        get { importError != nil }
        set { if !newValue { dismissImportError() } }
    }

    var isRemoveAlertPresented: Bool {
        get { bookToRemove != nil }
        set { if !newValue { removeCancelled() } }
    }

    var isBookActionAlertPresented: Bool {
        get { bookActionError != nil }
        set { if !newValue { dismissBookActionError() } }
    }

    var isRenameAlertPresented: Bool {
        get { bookToRename != nil }
        set { if !newValue { renameCancelled() } }
    }

    var isVoiceSearchAlertPresented: Bool {
        get { voiceSearchError != nil }
        set { if !newValue { voiceSearchError = nil } }
    }

    var accountActionTitle: String {
        cloudAccount == .signedIn ? "Sign out from Apple Account" : "Sign in from Apple Account"
    }

    private static let coverSize = CGSize(width: 400, height: 600)
    private let libCtrl: LibCtrl
    private let importCtrl: ImportCtrl
    private let appNav: AppNav
    private let speechSearchSvc: SpeechSearchSvc
    private let cloudSvc: (any CloudSvc)?
    private var voiceSearchSessionID: UUID?

    init(libCtrl: LibCtrl, importCtrl: ImportCtrl, appNav: AppNav, speechSearchSvc: SpeechSearchSvc = SpeechSearchSvc(),
         cloudSvc: (any CloudSvc)? = nil) {
        self.libCtrl = libCtrl
        self.importCtrl = importCtrl
        self.appNav = appNav
        self.speechSearchSvc = speechSearchSvc
        self.cloudSvc = cloudSvc
    }

    func onAppear() async {
        allBooks = (try? await libCtrl.loadLibrary()) ?? []
        await loadCovers()
        await refreshCloudAccount()
        await appBecameActive()
    }

    /// Imports the books shared from Apple Books while the app was away, and refreshes the index the Share extension reads.
    func appBecameActive() async {
        await oneAtATime { await self.importPending() }
    }

    /// An EPUB opened with iRead from another app ("Open in iRead").
    func fileOpened(_ url: URL) async {
        await oneAtATime { await self.importOpenedFile(url) }
    }

    private func oneAtATime<Result: Sendable>(_ work: @escaping @MainActor () async -> Result) async -> Result {
        let previous = lastImport
        let task = Task { @MainActor in
            await previous?.value
            return await work()
        }
        lastImport = Task { _ = await task.value }
        return await task.value
    }

    private func importPending() async {
        let added = await importCtrl.importPending()
        if let newest = added.last {
            newestImportedBookID = newest.id
        }
        if !added.isEmpty {
            await reloadLibrary()
            await loadCovers()
        }
        try? importCtrl.refreshIndex()
    }

    private func importOpenedFile(_ url: URL) async {
        do {
            newestImportedBookID = try await importCtrl.importBook(from: url).id
        } catch {
            importError = error.localizedDescription
        }
        await reloadLibrary()
        await loadCovers()
        try? importCtrl.refreshIndex()
    }

    func searchTapped() {
        isSearchActive = true
    }

    func searchFocusChanged(_ focused: Bool) {
        if focused { isSearchActive = true }
    }

    func searchDismissed() {
        searchText = ""
        isSearchActive = false
    }

    func viewModeSelected(_ mode: ViewMode) {
        viewMode = mode
    }

    func selectionModeTapped() {
        isSelectionMode = true
        selectedBookIDs.removeAll()
    }

    func selectionTapped(_ book: BookRecord) {
        guard isSelectionMode else { return }
        if selectedBookIDs.contains(book.id) {
            selectedBookIDs.remove(book.id)
        } else {
            selectedBookIDs.insert(book.id)
        }
    }

    func selectionModeDismissed() {
        isSelectionMode = false
        selectedBookIDs.removeAll()
    }

    func refreshCloudAccount() async {
        guard let cloudSvc else { return }
        cloudAccount = await cloudSvc.account()
    }

    func accountSettingsTapped() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(settingsURL)
    }

    func voiceSearchTapped() {
        if isVoiceSearchActive {
            voiceSearchSessionID = nil
            speechSearchSvc.stop()
            isVoiceSearchActive = false
            return
        }

        let sessionID = UUID()
        voiceSearchSessionID = sessionID
        isVoiceSearchActive = true
        Task {
            do {
                try await speechSearchSvc.start { [weak self] transcript in
                    guard self?.voiceSearchSessionID == sessionID else { return }
                    self?.searchText = transcript
                } onFailure: { [weak self] message in
                    guard self?.voiceSearchSessionID == sessionID else { return }
                    self?.voiceSearchError = message
                } onFinished: { [weak self] in
                    guard self?.voiceSearchSessionID == sessionID else { return }
                    self?.voiceSearchSessionID = nil
                    self?.isVoiceSearchActive = false
                }
                guard voiceSearchSessionID == sessionID else {
                    speechSearchSvc.stop()
                    return
                }
            } catch {
                guard voiceSearchSessionID == sessionID else { return }
                voiceSearchSessionID = nil
                isVoiceSearchActive = false
                voiceSearchError = error.localizedDescription
            }
        }
    }

    func dismissVoiceSearchError() {
        voiceSearchError = nil
    }

    func importTapped() {
        isImportPickerPresented = true
    }

    func importPickerCompleted(_ result: Result<[URL], any Error>) {
        Task { await importFiles(result) }
    }

    func sortChanged(_ sortOption: LibrarySortOption) {
        self.sortOption = sortOption
        newestImportedBookID = nil
    }

    /// True when every file is now in the library: imported, or already there. Each problem is listed once at the end,
    /// and a duplicate never stops the files after it.
    @discardableResult
    func importFiles(_ result: Result<[URL], any Error>) async -> Bool {
        isImportPickerPresented = false
        switch result {
        case .success(let urls):
            return await oneAtATime { await self.importPicked(urls) }
        case .failure(let error):
            // User cancellation is a normal document picker outcome.
            if (error as? CocoaError)?.code != .userCancelled {
                importError = error.localizedDescription
            }
            return false
        }
    }

    private func importPicked(_ urls: [URL]) async -> Bool {
        var problems: [String] = []
        var allInLibrary = true
        for url in urls {
            do {
                newestImportedBookID = try await importCtrl.importBook(from: url).id
            } catch ImportError.alreadyInLibrary(let title) {
                problems.append(ImportError.alreadyInLibrary(title: title).localizedDescription)
            } catch {
                allInLibrary = false
                problems.append(error.localizedDescription)
            }
        }
        await reloadLibrary()
        await loadCovers()
        try? importCtrl.refreshIndex()
        if !problems.isEmpty {
            importError = problems.joined(separator: "\n")
        }
        return allInLibrary
    }

    func dismissImportError() {
        importError = nil
    }

    func bookTapped(_ book: BookRecord) {
        guard !isSelectionMode else {
            selectionTapped(book)
            return
        }
        isSearchActive = false
        appNav.openReader(book: book)
    }

    func finishedToggled(_ book: BookRecord) {
        Task {
            await libCtrl.setFinished(!book.isFinished, for: book)
            await reloadLibrary()
        }
    }

    func resetProgressTapped(_ book: BookRecord) {
        Task {
            await libCtrl.resetProgress(for: book)
            await reloadLibrary()
        }
    }

    func removeTapped(_ book: BookRecord) {
        bookToRemove = book
    }

    func renameTapped(_ book: BookRecord) {
        bookToRename = book
        renameDraft = book.title
    }

    func renameCancelled() {
        bookToRename = nil
        renameDraft = ""
    }

    func renameConfirmed() {
        guard let book = bookToRename else { return }
        let title = renameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        bookToRename = nil
        renameDraft = ""
        Task {
            do {
                try libCtrl.rename(book, to: title)
                await reloadLibrary()
            } catch {
                bookActionError = error.localizedDescription
            }
        }
    }

    func removeCancelled() {
        bookToRemove = nil
    }

    func removeConfirmed() {
        guard let book = bookToRemove else { return }
        bookToRemove = nil
        Task {
            do {
                try await libCtrl.remove(book)
            } catch {
                bookActionError = error.localizedDescription
            }
            await reloadLibrary()
            try? importCtrl.refreshIndex()
        }
    }

    func dismissBookActionError() {
        bookActionError = nil
    }

    private func reloadLibrary() async {
        allBooks = (try? await libCtrl.loadLibrary()) ?? allBooks
    }

    private func loadCovers() async {
        for book in allBooks where covers[book.id] == nil {
            guard let data = await libCtrl.cover(for: book.id) else { continue }
            // Shrunk once here, so scrolling the grid never decodes a full-size cover.
            covers[book.id] = await UIImage(data: data)?.byPreparingThumbnail(ofSize: Self.coverSize)
        }
    }
}
