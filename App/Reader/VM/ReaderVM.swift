import Foundation
import Observation

@MainActor
@Observable
final class ReaderVM {
    enum Sheet: Identifiable {
    case contents
        case search(SearchVM)
        case themeSettings

        var id: String {
            switch self {
            case .contents: "contents"
            case .search: "search"
            case .themeSettings: "themeSettings"
            }
        }
    }

    let readerSettingsVM: ReaderSettingsVM
    let referenceVM: ReferenceVM
    let ratingVM: RatingVM
    private(set) var title = ""
    private(set) var chapterTitles: [String] = []
    private(set) var pages: [Page] = []
    private(set) var shownPage: Page?
    private(set) var hasFailedToOpen = false
    /// Focus mode hides the reading controls, leaving only the page. Off when the book opens.
    private(set) var isFocusMode = false
    private(set) var sheet: Sheet?
    #if DEBUG
    private(set) var isUnderlineDebugShown = false
    #endif

    private var chapterStartPages: [Int] = []
    private var pageCount: Int?
    private var requestedViewport = Viewport(size: .zero)
    private var progressTask: Task<Void, Never>?
    private let book: BookRecord
    private let readerCtrl: ReaderCtrl
    private let progressCtrl: ProgressCtrl
    private let readerStateCtrl: ReaderStateCtrl
    private let appNav: AppNav

    var chapterTitle: String {
        shownPage.map { chapterTitles[$0.chapterIndex] } ?? ""
    }

    var pageLabel: String {
        guard let shownPage else { return "" }
        guard !isFocusMode, let pageCount else { return "Page \(shownPage.number)" }
        return "Page \(shownPage.number) of \(pageCount)"
    }

    init(book: BookRecord, readerCtrl: ReaderCtrl, progressCtrl: ProgressCtrl, readerStateCtrl: ReaderStateCtrl, appNav: AppNav,
         readerSettingsVM: ReaderSettingsVM, referenceVM: ReferenceVM, ratingVM: RatingVM) {
        self.book = book
        self.readerCtrl = readerCtrl
        self.progressCtrl = progressCtrl
        self.readerStateCtrl = readerStateCtrl
        self.appNav = appNav
        self.readerSettingsVM = readerSettingsVM
        self.referenceVM = referenceVM
        self.ratingVM = ratingVM
        readerSettingsVM.onSettingsChanged = { [weak self] in
            Task { await self?.showCurrentPage() }
        }
        referenceVM.onShowPage = { [weak self] page, underlineID in self?.show(page, highlighting: underlineID) }
    }

    func startPageLabel(ofChapter index: Int) -> String {
        chapterStartPages.indices.contains(index) ? "\(chapterStartPages[index])" : ""
    }

    func onAppear(viewport: Viewport) async {
        requestedViewport = viewport
        do {
            try await readerCtrl.openBook()
            await readerSettingsVM.bookOpened()
            if let readingProgress = await progressCtrl.savedProgress() {
                let isRestored = await readerCtrl.restorePosition(from: readingProgress)
                await progressCtrl.positionRestored(isRestored)
            }
            await referenceVM.bookOpened()
            await ratingVM.bookOpened()
            title = book.title
            chapterTitles = await readerCtrl.chapterTitles()
            await showCurrentPage()
        } catch {
            hasFailedToOpen = true
        }
    }

    func viewportChanged(_ viewport: Viewport) {
        requestedViewport = viewport
        guard shownPage != nil else { return }
        Task { await showCurrentPage() }
    }

    /// Like Apple Books: turning the page turns focus mode on, tapping the middle of the page toggles it.
    func pageChanged(_ page: Page) {
        isFocusMode = true
        show(page)
    }

    func pageCenterTapped() {
        isFocusMode.toggle()
    }

    func backTapped() {
        Task {
            // Waits for the last page turn's save first, so it isn't lost.
            await progressTask?.value
            progressTask?.cancel()
            progressTask = nil
            await progressCtrl.saveNow()
            referenceVM.close()
            appNav.closeReader()
        }
    }

    func appBackgrounded() {
        Task { await progressCtrl.saveNow() }
        referenceVM.appBackgrounded()
    }

    func appForegrounded() {
        referenceVM.appForegrounded()
        ratingVM.appForegrounded()
    }

    #if DEBUG
    var isUnderlineDebugSheetPresented: Bool {
        get { isUnderlineDebugShown }
        set { if !newValue { underlineDebugDismissed() } }
    }

    func underlineDebugTapped() {
        isUnderlineDebugShown = true
    }

    func underlineDebugDismissed() {
        isUnderlineDebugShown = false
    }
    #endif

    func contentsTapped() {
        sheet = .contents
    }

    func searchTapped() {
        sheet = .search(SearchVM(
            search: { [readerCtrl] in await readerCtrl.search($0) },
            readerStateCtrl: readerStateCtrl,
            onResultPicked: { [weak self] result in self?.searchResultPicked(result) }
        ))
    }

    func themeSettingsTapped() {
        sheet = .themeSettings
        readerSettingsVM.themeSettingsShown()
    }

    func sheetDismissed() {
        sheet = nil
    }

    func chapterTapped(_ index: Int) {
        sheet = nil
        Task { show(await readerCtrl.firstPage(ofChapter: index)) }
    }

    private func searchResultPicked(_ result: SearchResult) {
        sheet = nil
        Task { show(await readerCtrl.page(containing: result.position), searchResult: result) }
    }

    private func loadPages(around page: Page) {
        Task {
            let pages = await readerCtrl.pages(around: page)
            guard shownPage == page else { return }
            self.pages = pages
            updateReferenceVM()
            await referenceVM.loadMarks()
        }
    }

    private func showCurrentPage() async {
        let viewport = requestedViewport
        let settings = readerSettingsVM.settings
        let page = await readerCtrl.currentPage(viewport: viewport, settings: settings)
        guard viewport == requestedViewport, settings == readerSettingsVM.settings else { return }
        readerSettingsVM.layoutChanged(to: settings)
        shownPage = page
        pages = [page]
        referenceVM.layoutChanged()
        updateReferenceVM()
        loadPages(around: page)
        loadPageTotals()
    }

    private func show(_ page: Page, highlighting underlineID: String? = nil, searchResult: SearchResult? = nil) {
        referenceVM.pageShown(highlighting: underlineID, searchResult: searchResult)
        shownPage = page
        updateReferenceVM()
        loadPages(around: page)
        let previousTask = progressTask
        progressTask = Task {
            await previousTask?.value
            let readingProgress = await readerCtrl.pageChanged(to: page)
            await progressCtrl.pageRead(readingProgress)
        }
    }

    #if DEBUG
    func makeUnderlineDebugVM() -> UnderlineDebugVM {
        UnderlineDebugVM(refCtrl: referenceVM.refCtrl, ratingCtrl: ratingVM.ratingCtrl, chapterIndex: shownPage?.chapterIndex)
    }
    #endif

    private func updateReferenceVM() {
        referenceVM.update(shownPage: shownPage, loadedPages: pages)
    }

    private func loadPageTotals() {
        chapterStartPages = []
        pageCount = nil
        Task {
            let counts = await readerCtrl.chapterPageCounts()
            chapterStartPages = counts.indices.map { index in counts[..<index].reduce(1, +) }
            pageCount = counts.reduce(0, +)
        }
    }
}
