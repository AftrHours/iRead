import Foundation
import Observation

@MainActor
@Observable
final class ReaderVM {
    enum Sheet: Identifiable {
        case contents
        case search(SearchVM)
        case characters
        case themeSettings

        var id: String {
            switch self {
            case .contents: "contents"
            case .search: "search"
            case .characters: "characters"
            case .themeSettings: "themeSettings"
            }
        }
    }

    let readerSettingsVM: ReaderSettingsVM
    let referenceVM: ReferenceVM
    let ratingVM: RatingVM
    let characterVM: CharacterVM
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

    /// Where the page's parts go. nil until the screen has been measured.
    private(set) var layout: PageLayout?

    private var readingFocus: ReaderFocusRequest?
    @ObservationIgnored private var lastDeliveredFocus: UUID?

    private(set) var completedPassageSpeech: UUID?

    var isPassageSpeechPending: Bool {
        guard case .passage? = readingFocus?.target, referenceVM.jumpedPassageText != nil else { return false }
        return completedPassageSpeech != readingFocus?.id
    }

    func passageSpeechEnded(text: String, finished: Bool, isActive: Bool) {
        guard isPassageSpeechPending, let request = readingFocus, lastDeliveredFocus == request.id,
              case .passage(text) = request.target else { return }
        if finished {
            completedPassageSpeech = request.id
        } else if isActive {
            replayPendingPassage()
        }
    }

    func replayPendingPassage() {
        guard isPassageSpeechPending, let shownPage else { return }
        readingFocus = ReaderFocusRequest(from: shownPage, to: shownPage, passage: referenceVM.jumpedPassageText)
    }

    func claimReadingFocus(_ id: UUID) -> Bool {
        guard readingFocus?.id == id, lastDeliveredFocus != id else { return false }
        lastDeliveredFocus = id
        return true
    }

    private var chapterStartPages: [Int] = []
    private var pageCount: Int?
    private var isBookOpen = false
    private var systemIsDark = false
    private var isRegularWidth = false
    private var progressTask: Task<Void, Never>?
    private let book: BookRecord
    private let readerCtrl: ReaderCtrl
    private let progressCtrl: ProgressCtrl
    private let readerStateCtrl: ReaderStateCtrl
    private let appNav: AppNav

    /// The marks to draw: underlines disappear in focus mode, with the bars. A highlight stays: it is the passage a jump landed on.
    var visibleMarks: [Int: [Mark]] {
        guard isFocusMode else { return referenceVM.marks }
        return referenceVM.marks.mapValues { $0.filter { !$0.isUnderline } }
    }

    var theme: ReadingTheme {
        readerSettingsVM.layoutSettings.theme
    }

    /// Whether the page is dark, so its controls are light: the reading mode's choice, or the device's for Match Device.
    var isDarkPage: Bool {
        theme.isDarkPage(isDarkMode: readerSettingsVM.isDarkMode ?? systemIsDark)
    }

    /// The reading mode's choice of light or dark, nil to leave the device's style alone.
    var forcedDarkMode: Bool? {
        readerSettingsVM.isDarkMode
    }

    /// On a full-width iPad the settings are a panel attached to the bottom edge, not iOS's floating form sheet.
    var isSettingsPanelShown: Bool {
        guard isRegularWidth, case .themeSettings = sheet else { return false }
        return true
    }

    /// The sheet to present: everything but the iPad's settings panel. Setting it to nil closes the sheet.
    var presentedSheet: Sheet? {
        get { isSettingsPanelShown ? nil : sheet }
        set { if newValue == nil { sheetDismissed() } }
    }

    /// Everything the pagers draw, nil until there is a page and the screen has been measured.
    var pageContent: PageContent? {
        guard let layout, let shownPage else { return nil }
        let chromes = Dictionary((pages + [shownPage]).map { ($0.number, chrome(for: $0)) }, uniquingKeysWith: { first, _ in first })
        return PageContent(pages: pages, shownPage: shownPage, settings: readerSettingsVM.layoutSettings, layout: layout,
                           marks: visibleMarks, chromes: chromes, selectedUnderlineID: referenceVM.selectedUnderlineID,
                           showsMentionTag: referenceVM.jumpedPassageText != nil, readingFocus: readingFocus)
    }

    /// The iPad's reference card on a full-width screen, the iPhone's on a narrow one.
    var isCardForPad: Bool {
        isRegularWidth
    }

    private var cardHeight: CGFloat {
        isCardForPad ? RefPopoverPadKnobs.size.height : RefPopoverPhoneKnobs.size.height
    }

    /// Whether the reference card opens below its underline: when it fits there, else above it. A popover only takes one fixed edge,
    /// or nil to let the system pick the roomiest side, which puts the card above mid-page underlines.
    var isCardBelowUnderline: Bool {
        guard let layout else { return true }
        return layout.text.maxY - referenceVM.cardAnchor.maxY >= cardHeight
    }

    /// What a page shows above and below its text. Each page carries its own, so it turns with the page.
    private func chrome(for page: Page) -> PageChrome {
        PageChrome(title: title, chapterTitle: chapterTitle(of: page), pageLabel: pageLabel(for: page), isReadingMode: isFocusMode,
                   progress: isFocusMode ? nil : share(of: page.number), returnMark: returnMark)
    }

    private var returnMark: Double? {
        guard referenceVM.returnPrompt == .canReturn, let number = referenceVM.returnPageNumber else { return nil }
        return share(of: number)
    }

    private func share(of number: Int) -> Double? {
        guard let pageCount, pageCount > 0 else { return nil }
        return min(1, max(0, Double(number) / Double(pageCount)))
    }

    private func chapterTitle(of page: Page) -> String {
        chapterTitles.indices.contains(page.chapterIndex) ? chapterTitles[page.chapterIndex] : ""
    }

    /// "Page 12 of 300", or "Returned to page 12" for a moment after returning.
    private func pageLabel(for page: Page) -> String {
        if case .returned(let message) = referenceVM.returnPrompt, page.number == shownPage?.number { return message }
        guard !isFocusMode, let pageCount else { return "Page \(page.number)" }
        return "Page \(page.number) of \(pageCount)"
    }

    init(book: BookRecord, readerCtrl: ReaderCtrl, progressCtrl: ProgressCtrl, readerStateCtrl: ReaderStateCtrl, appNav: AppNav,
         readerSettingsVM: ReaderSettingsVM, referenceVM: ReferenceVM, ratingVM: RatingVM, characterVM: CharacterVM) {
        self.book = book
        self.readerCtrl = readerCtrl
        self.progressCtrl = progressCtrl
        self.readerStateCtrl = readerStateCtrl
        self.appNav = appNav
        self.readerSettingsVM = readerSettingsVM
        self.referenceVM = referenceVM
        self.ratingVM = ratingVM
        self.characterVM = characterVM
        readerSettingsVM.onSettingsChanged = { [weak self] in
            Task { await self?.showCurrentPage() }
        }
        referenceVM.onShowPage = { [weak self] page, passage in self?.show(page, highlighting: passage) }
        characterVM.onJump = { [weak self] passage in self?.characterPassagePicked(passage) }
    }

    func startPageLabel(ofChapter index: Int) -> String {
        chapterStartPages.indices.contains(index) ? "\(chapterStartPages[index])" : ""
    }

    /// The screen was measured, or changed (a rotation, a split view). Pages are laid out again when the text's room changed.
    func screenChanged(_ screen: ScreenGeometry) {
        let previousViewport = layout?.viewport
        let newLayout = PageLayout(screen)
        layout = newLayout
        guard isBookOpen, newLayout.viewport != previousViewport else { return }
        Task { await showCurrentPage() }
    }

    func systemAppearanceChanged(isDark: Bool) {
        systemIsDark = isDark
    }

    func widthClassChanged(isRegular: Bool) {
        isRegularWidth = isRegular
    }

    func onAppear() async {
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
            isBookOpen = true
            await showCurrentPage()
        } catch {
            hasFailedToOpen = true
        }
    }

    /// Like Apple Books: turning the page turns focus mode on, tapping the middle of the page toggles it.
    func pageChanged(_ page: Page) {
        isFocusMode = true
        show(page)
    }

    /// A tap first clears a jumped-to passage's highlight.
    func pageCenterTapped() {
        guard !referenceVM.hasPassageHighlight else { return referenceVM.passageDismissed() }
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

    func charactersTapped() {
        sheet = .characters
        characterVM.sheetOpened(at: shownPage)
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

    private func characterPassagePicked(_ passage: ContextPassage) {
        sheet = nil
        referenceVM.jumpToPassage(passage)
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
        guard let viewport = layout?.viewport else { return }
        let settings = readerSettingsVM.settings
        let page = await readerCtrl.currentPage(viewport: viewport, settings: settings)
        guard viewport == layout?.viewport, settings == readerSettingsVM.settings else { return }
        readerSettingsVM.layoutChanged(to: settings)
        if shownPage == nil { readingFocus = ReaderFocusRequest(from: nil, to: page) }
        shownPage = page
        pages = [page]
        referenceVM.layoutChanged()
        updateReferenceVM()
        loadPages(around: page)
        loadPageTotals()
        await referenceVM.refreshReturnPage()
    }

    private func show(_ page: Page, highlighting passage: ContextPassage? = nil, searchResult: SearchResult? = nil) {
        referenceVM.pageShown(highlighting: passage, searchResult: searchResult)
        completedPassageSpeech = nil
        readingFocus = ReaderFocusRequest(from: shownPage, to: page, passage: referenceVM.jumpedPassageText)
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
