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
    private let speech = LibrarySpeechSearch()
    private var speechSession: UUID?
    @ObservationIgnored private var speechStart: Task<Void, Never>?
    var isDictating: Bool { speechSession != nil }
    var voiceSearchError: String?

    func voiceSearchTapped() {
        guard !isDictating else { stopDictation(); return }
        searchTapped()
        let id = UUID()
        speechSession = id
        speechStart = Task { [self] in
            do {
                try await speech.start { [weak self] text, final, failed in
                    guard let self, speechSession == id else { return }
                    if let text { searchText = text }
                    if final || failed { stopDictation() }
                    if failed && searchText.isEmpty { voiceSearchError = LibrarySpeechSearch.Failure.unavailable.localizedDescription }
                }
            } catch {
                guard speechSession == id else { return }
                stopDictation()
                voiceSearchError = error.localizedDescription
            }
        }
    }

    func stopDictation() {
        guard speechSession != nil else { return }
        speechSession = nil
        speechStart?.cancel()
        speechStart = nil
        speech.stop()
    }

    func editQuery(_ text: String) {
        stopDictation()
        searchText = text
    }
    private(set) var isSearchActive = false
    private(set) var isLibraryScrolled = false
    var isOptionsMenuPresented = false
    var isImportPickerPresented = false
    private(set) var isSelectionMode = false
    private(set) var selectedBookIDs: Set<UUID> = []
    var renameDraft = ""
    private(set) var allBooks: [BookRecord] = []
    private(set) var viewMode = ViewMode.grid
    private(set) var sortOption = LibrarySortOption.latestRead
    private(set) var importError: String?
    private(set) var covers: [UUID: UIImage] = [:]
    private(set) var pendingRemoval: [BookRecord] = []
    private(set) var isRemovingBooks = false
    private(set) var bookToRename: BookRecord?
    private(set) var bookActionError: String?
    private(set) var cloudAccount: CloudAccount = .unknown
    private var pickerFlow: String?
    var betaReport: BetaReportDocument?
    var isExportingBetaReport = false

    private(set) var sharesBetaAnalytics = BetaAnalytics.shared.cloudDelivery.isSharing
    var isBetaConsentPresented = false

    func betaSharingTapped() {
        if sharesBetaAnalytics {
            setBetaSharing(false)
        } else if BetaAnalytics.shared.cloudDelivery.isAvailable {
            isBetaConsentPresented = true
        } else {
            bookActionError = "This build can export beta analytics locally. CloudKit sharing requires an iCloud-enabled build."
        }
    }

    func allowBetaSharing() {
        setBetaSharing(true)
    }

    private func setBetaSharing(_ enabled: Bool) {
        do {
            try BetaAnalytics.shared.cloudDelivery.setSharing(enabled)
        } catch {
            bookActionError = "Couldn’t update beta analytics sharing."
        }
        sharesBetaAnalytics = BetaAnalytics.shared.cloudDelivery.isSharing
    }

    func exportBetaReport() {
        Task {
            do {
                betaReport = try await BetaReportDocument(data: BetaAnalytics.shared.export())
                isExportingBetaReport = true
            } catch {
                bookActionError = "Couldn’t prepare the beta analytics report."
            }
        }
    }

    func exportCompleted(_ result: Result<URL, Error>) {
        betaReport = nil
        if case .failure(let error) = result, (error as? CocoaError)?.code != .userCancelled {
            bookActionError = "Couldn’t save the beta analytics report."
        }
    }

    private(set) var newestImportedBookID: UUID?
    private var lastImport: Task<Void, Never>?

    var books: [BookRecord] {
        LibrarySorter.sorted(allBooks, by: sortOption, pinning: sortOption == .latestRead ? newestImportedBookID : nil)
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
        if showsSearchEmptyState { return "Oopsiee we can’t find that :(" }
        if allBooks.isEmpty { return "Let’s add your first book!" }
        return "No books found"
    }

    var emptyStateMessage: String {
        if allBooks.isEmpty && !showsSearchEmptyState { return "Tap the “+” button to import an EPUB file." }
        return "Try searching by title or author name."
    }

    var isImportAlertPresented: Bool {
        get { importError != nil }
        set { if !newValue { dismissImportError() } }
    }

    var isRemoveAlertPresented: Bool {
        get { !pendingRemoval.isEmpty }
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

    var accountActionTitle: String {
        cloudAccount == .signedIn ? "Sign out from Apple Account" : "Sign in from Apple Account"
    }

    private static let coverSize = CGSize(width: 400, height: 600)
    private let libCtrl: LibCtrl
    private let importCtrl: ImportCtrl
    private let appNav: AppNav
    private let cloudSvc: (any CloudSvc)?

    init(libCtrl: LibCtrl, importCtrl: ImportCtrl, appNav: AppNav, cloudSvc: (any CloudSvc)? = nil) {
        self.libCtrl = libCtrl
        self.importCtrl = importCtrl
        self.appNav = appNav
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

    /// An EPUB opened with Refrn from another app ("Open in Refrn").
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
        guard !isSelectionMode else { return }
        isSearchActive = true
    }

    func libraryScrolled(to offset: CGFloat, headerHeight: CGFloat) {
        let isScrolled = offset >= headerHeight
        guard isLibraryScrolled != isScrolled else { return }
        isLibraryScrolled = isScrolled
    }

    func searchFocusChanged(_ focused: Bool) {
        if focused { searchTapped() }
    }

    func searchDismissed() {
        editQuery("")
        isSearchActive = false
    }

    func viewModeSelected(_ mode: ViewMode) {
        viewMode = mode
    }

    func selectionModeTapped() {
        searchDismissed()
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
        searchDismissed()
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

    func importTapped() {
        pickerStarted(source: "library")
        isImportPickerPresented = true
    }

    func pickerStarted(source: String) {
        guard pickerFlow == nil else { return }
        pickerFlow = UUID().uuidString
        BetaAnalytics.shared.record(.pickerStarted, flow: pickerFlow, category: source)
    }

    func pickerFailed(_ error: Error) {
        guard let pickerFlow else { return }
        self.pickerFlow = nil
        let cancelled = (error as? CocoaError)?.code == .userCancelled
        BetaAnalytics.shared.record(cancelled ? .pickerCancelled : .pickerFailed, flow: pickerFlow,
                                    category: cancelled ? nil : BetaAnalytics.category(error), feature: "picker")
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
    func importFiles(_ result: Result<[URL], any Error>, didImport: (([UUID]) -> Void)? = nil) async -> Bool {
        isImportPickerPresented = false
        switch result {
        case .success(let urls):
            let flow = pickerFlow
            pickerFlow = nil
            return await oneAtATime { await self.importPicked(urls, flow: flow, didImport: didImport) }
        case .failure(let error):
            pickerFailed(error)
            // User cancellation is a normal document picker outcome.
            if (error as? CocoaError)?.code != .userCancelled {
                importError = error.localizedDescription
            }
            return false
        }
    }

    private func importPicked(_ urls: [URL], flow: String?, didImport: (([UUID]) -> Void)?) async -> Bool {
        var insertedIDs: [UUID] = []
        var problems: [String] = []
        var allInLibrary = true
        for url in urls {
            do {
                let book = try await importCtrl.importBook(from: url, source: "picker", picker: flow)
                newestImportedBookID = book.id
                insertedIDs.append(book.id)
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
        didImport?(insertedIDs)
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
        stopDictation()
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
        pendingRemoval = [book]
    }

    private var visibleBookIDs: Set<UUID> { Set(visibleBooks.map(\.id)) }

    var areVisibleBooksSelected: Bool {
        let visible = visibleBookIDs
        return !visible.isEmpty && visible.isSubset(of: selectedBookIDs)
    }

    func toggleVisibleSelection() {
        let visible = visibleBookIDs
        if visible.isSubset(of: selectedBookIDs) {
            selectedBookIDs.subtract(visible)
        } else {
            selectedBookIDs.formUnion(visible)
        }
    }

    func removeSelectionTapped() {
        pendingRemoval = allBooks.filter { selectedBookIDs.contains($0.id) }
    }

    var removalQuestion: String {
        let subject = pendingRemoval.count > 1 ? "these \(pendingRemoval.count) books" : "this book"
        return "Do you want to delete \(subject) from iCloud and all your iCloud devices?"
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
                BetaAnalytics.shared.record(.recoverableError, category: BetaAnalytics.category(error), feature: "rename")
                bookActionError = error.localizedDescription
            }
        }
    }

    func removeCancelled() {
        pendingRemoval.removeAll()
    }

    func removeConfirmed() {
        let books = pendingRemoval
        guard !books.isEmpty, !isRemovingBooks else { return }
        pendingRemoval.removeAll()
        isRemovingBooks = true
        Task {
            defer { isRemovingBooks = false }
            var failures: [String] = []
            for book in books {
                do {
                    try await libCtrl.remove(book)
                    selectedBookIDs.remove(book.id)
                } catch {
                    BetaAnalytics.shared.record(.recoverableError, category: BetaAnalytics.category(error), feature: "remove")
                    failures.append("\(book.title): \(error.localizedDescription)")
                }
            }
            await reloadLibrary()
            try? importCtrl.refreshIndex()
            if allBooks.isEmpty && isSelectionMode { selectionModeDismissed() }
            if !failures.isEmpty { bookActionError = failures.joined(separator: "\n") }
        }
    }

    func dismissBookActionError() {
        bookActionError = nil
    }

    func prepareOnboardingBooks() async {
        await reloadLibrary()
        await loadCovers()
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
