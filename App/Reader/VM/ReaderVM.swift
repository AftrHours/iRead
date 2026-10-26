import Foundation
import Observation

@MainActor
@Observable
final class ReaderVM {
    enum Sheet: Identifiable {
        case contents
        case search(SearchVM)
        case themeSettings
        case chapterSymbols
        case editSymbol(Entity)

        var id: String {
            switch self {
            case .contents: "contents"
            case .search: "search"
            case .themeSettings: "themeSettings"
            case .chapterSymbols: "chapterSymbols"
            case .editSymbol(let entity): "editSymbol \(entity.id)"
            }
        }
    }

    let readerSettingsVM: ReaderSettingsVM
    let referenceVM: ReferenceVM
    private(set) var title = ""
    private(set) var chapterTitles: [String] = []
    private(set) var pages: [Page] = []
    private(set) var shownPage: Page?
    private(set) var hasFailedToOpen = false
    private(set) var areControlsShown = true
    private(set) var isMenuShown = false
    private(set) var sheet: Sheet?

    private var chapterStartPages: [Int] = []
    private var sheetAfterMenu: Sheet?
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
        guard areControlsShown, let pageCount else { return "Page \(shownPage.number)" }
        return "Page \(shownPage.number) of \(pageCount)"
    }

    init(book: BookRecord, readerCtrl: ReaderCtrl, progressCtrl: ProgressCtrl, readerStateCtrl: ReaderStateCtrl, appNav: AppNav,
         readerSettingsVM: ReaderSettingsVM, referenceVM: ReferenceVM) {
        self.book = book
        self.readerCtrl = readerCtrl
        self.progressCtrl = progressCtrl
        self.readerStateCtrl = readerStateCtrl
        self.appNav = appNav
        self.readerSettingsVM = readerSettingsVM
        self.referenceVM = referenceVM
        readerSettingsVM.onSettingsChanged = { [weak self] in
            Task { await self?.showCurrentPage() }
        }
        referenceVM.onShowPage = { [weak self] page, mentionIndex in self?.show(page, highlighting: mentionIndex) }
        referenceVM.onEditSymbol = { [weak self] entity in self?.sheet = .editSymbol(entity) }
    }

    func startPageLabel(ofChapter index: Int) -> String {
        chapterStartPages.indices.contains(index) ? "\(chapterStartPages[index])" : ""
    }

    func onAppear(viewport: Viewport) async {
        requestedViewport = viewport
        referenceVM.onAppear()
        do {
            try await readerCtrl.openBook()
            await readerSettingsVM.bookOpened()
            if let readingProgress = await progressCtrl.savedProgress() {
                let isRestored = await readerCtrl.restorePosition(from: readingProgress)
                await progressCtrl.positionRestored(isRestored)
            }
            await referenceVM.bookOpened()
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

    /// Like Apple Books: turning the page hides the controls, tapping the middle of the page toggles them.
    func pageChanged(_ page: Page) {
        areControlsShown = false
        show(page)
    }

    func pageCenterTapped() {
        areControlsShown.toggle()
    }

    func backTapped() {
        Task {
            await progressCtrl.saveNow()
            appNav.closeReader()
        }
    }

    func appBackgrounded() {
        Task { await progressCtrl.saveNow() }
        referenceVM.appBackgrounded()
    }

    func appForegrounded() {
        referenceVM.appForegrounded()
    }

    func menuTapped() {
        isMenuShown = true
    }

    func menuDismissed() {
        isMenuShown = false
    }

    /// A sheet asked for from the menu opens only once the menu has fully closed,
    /// because iOS drops a sheet that is presented while the menu is still closing.
    func menuDisappeared() {
        guard let sheetAfterMenu else { return }
        sheet = sheetAfterMenu
        self.sheetAfterMenu = nil
    }

    func contentsTapped() {
        openAfterMenu(.contents)
    }

    func searchTapped() {
        openAfterMenu(.search(SearchVM(readerCtrl: readerCtrl, readerStateCtrl: readerStateCtrl) { [weak self] result in
            self?.searchResultPicked(result)
        }))
    }

    func themeSettingsTapped() {
        openAfterMenu(.themeSettings)
        readerSettingsVM.themeSettingsShown()
    }

    func chapterSymbolsTapped() {
        referenceVM.chapterSymbolsShown()
        openAfterMenu(.chapterSymbols)
    }

    func sheetDismissed() {
        sheet = nil
    }

    func chapterTapped(_ index: Int) {
        sheet = nil
        Task { show(await readerCtrl.firstPage(ofChapter: index)) }
    }

    private func openAfterMenu(_ sheet: Sheet) {
        sheetAfterMenu = sheet
        isMenuShown = false
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

    private func show(_ page: Page, highlighting mentionIndex: Int? = nil, searchResult: SearchResult? = nil) {
        referenceVM.pageShown(highlighting: mentionIndex, searchResult: searchResult)
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

    private func updateReferenceVM() {
        referenceVM.update(
            shownPage: shownPage,
            loadedPages: pages,
            areSymbolsShown: readerSettingsVM.layoutSettings.areSymbolsShown
        )
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

extension ReaderVM {
    typealias ReferenceCard = ReferenceVM.ReferenceCard
}
