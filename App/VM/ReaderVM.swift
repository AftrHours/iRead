import Foundation
import Observation

@MainActor
@Observable
final class ReaderVM {
    enum Sheet: Identifiable {
        case contents
        case search(SearchVM)
        case themeSettings
        case symbolDetails

        var id: String {
            switch self {
            case .contents: "contents"
            case .search: "search"
            case .themeSettings: "themeSettings"
            case .symbolDetails: "symbolDetails"
            }
        }
    }

    enum Card: Identifiable {
        case reference(ReferenceCard)
        case symbol(Entity)

        var id: String {
            switch self {
            case .reference(let card): "reference \(card.mentionIndex)"
            case .symbol(let entity): "symbol \(entity.id)"
            }
        }
    }

    struct ReferenceCard {
        let mentionIndex: Int
        let name: String
        let location: String
        let quote: String
    }

    private(set) var settings = ReadingSettings()
    private(set) var layoutSettings = ReadingSettings()
    private(set) var brightness = 0.0
    private(set) var title = ""
    private(set) var chapterTitles: [String] = []
    private(set) var pages: [Page] = []
    private(set) var shownPage: Page?
    private(set) var viewport = Viewport(size: .zero, bodyFontSize: 0)
    private(set) var hasFailedToOpen = false
    private(set) var isMenuShown = false
    private(set) var sheet: Sheet?
    private(set) var marks: [Int: [Mark]] = [:]
    private(set) var card: Card?
    private(set) var cardAnchor = CGRect.zero
    private(set) var canReturn = false
    private(set) var toastText: String?

    private var chapterStartPages: [Int] = []
    private var pageCount: Int?
    private var requestedViewport = Viewport(size: .zero, bodyFontSize: 0)
    private var highlightedMentionIndex: Int?
    private let readerCtrl: ReaderCtrl
    private let refCtrl: RefCtrl
    private let appNav: AppNav

    var chapterTitle: String {
        shownPage.map { chapterTitles[$0.chapterIndex] } ?? ""
    }

    var pageLabel: String {
        guard let shownPage else { return "" }
        guard let pageCount else { return "Page \(shownPage.number)" }
        return "Page \(shownPage.number) of \(pageCount)"
    }

    init(readerCtrl: ReaderCtrl, refCtrl: RefCtrl, appNav: AppNav) {
        self.readerCtrl = readerCtrl
        self.refCtrl = refCtrl
        self.appNav = appNav
    }

    func startPageLabel(ofChapter index: Int) -> String {
        chapterStartPages.indices.contains(index) ? "\(chapterStartPages[index])" : ""
    }

    func onAppear(viewport: Viewport) async {
        requestedViewport = viewport
        do {
            title = try await readerCtrl.openBook().title
            chapterTitles = await readerCtrl.chapterTitles()
            settings = await readerCtrl.settings()
            canReturn = await readerCtrl.hasReturnPosition()
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

    func pageChanged(_ page: Page) {
        show(page)
    }

    func backTapped() {
        Task {
            await readerCtrl.saveNow()
            appNav.closeReader()
        }
    }

    func appBackgrounded() {
        Task { await readerCtrl.saveNow() }
    }

    func menuTapped() {
        isMenuShown = true
    }

    func menuDismissed() {
        isMenuShown = false
    }

    func contentsTapped() {
        isMenuShown = false
        sheet = .contents
    }

    func searchTapped() {
        isMenuShown = false
        sheet = .search(SearchVM(readerCtrl: readerCtrl) { [weak self] result in
            self?.searchResultPicked(result)
        })
    }

    func themeSettingsTapped() {
        isMenuShown = false
        sheet = .themeSettings
        Task { brightness = await readerCtrl.brightness() }
    }

    func textSizeDecreased() {
        changeSettings { $0.textSizeStep = max($0.textSizeStep - 1, ReadingSettings.textSizeSteps.lowerBound) }
    }

    func textSizeIncreased() {
        changeSettings { $0.textSizeStep = min($0.textSizeStep + 1, ReadingSettings.textSizeSteps.upperBound) }
    }

    func lineSpacingDecreased() {
        changeSettings { $0.lineSpacingStep = max($0.lineSpacingStep - 1, ReadingSettings.lineSpacingSteps.lowerBound) }
    }

    func lineSpacingIncreased() {
        changeSettings { $0.lineSpacingStep = min($0.lineSpacingStep + 1, ReadingSettings.lineSpacingSteps.upperBound) }
    }

    func themeTapped(_ index: Int) {
        changeSettings { $0.themeIndex = index }
    }

    func brightnessChanged(_ brightness: Double) {
        self.brightness = brightness
        Task { await readerCtrl.changeBrightness(to: brightness) }
    }

    func markTapped(_ mark: Mark, at anchor: CGRect) {
        Task {
            guard let entity = try? await refCtrl.entity(forMention: mark.mentionIndex) else { return }
            cardAnchor = anchor
            guard mark.kind == .underline else {
                card = .symbol(entity)
                return
            }
            guard let passage = try? await refCtrl.passage(forMention: mark.mentionIndex) else { return }
            let passagePage = await readerCtrl.page(containing: passage.start)
            card = .reference(ReferenceCard(
                mentionIndex: mark.mentionIndex,
                name: entity.name,
                location: "\(chapterTitles[passagePage.chapterIndex]) • Page \(passagePage.number)",
                quote: "“\(passage.text)”"
            ))
        }
    }

    func cardDismissed() {
        card = nil
    }

    func editSymbolTapped() {
        card = nil
        sheet = .symbolDetails
    }

    func jumpToPassageTapped() {
        guard case .reference(let referenceCard) = card, let shownPage else { return }
        card = nil
        canReturn = true
        Task {
            await readerCtrl.saveReturnPosition(from: shownPage)
            guard let passage = try? await refCtrl.passage(forMention: referenceCard.mentionIndex) else { return }
            show(await readerCtrl.page(containing: passage.start), highlighting: referenceCard.mentionIndex)
        }
    }

    func returnToReadingTapped() {
        canReturn = false
        Task {
            guard let page = await readerCtrl.returnPage() else { return }
            await readerCtrl.clearReturnPosition()
            show(page)
            toastText = "Returned to page \(page.number)"
            try? await Task.sleep(for: .seconds(2))
            toastText = nil
        }
    }

    func returnDismissed() {
        canReturn = false
        highlightedMentionIndex = nil
        Task {
            await readerCtrl.clearReturnPosition()
            await loadMarks()
        }
    }

    func symbolsToggled(_ isOn: Bool) {
        changeSettings { $0.areSymbolsShown = isOn }
    }

    func symbolDetailsTapped() {
        isMenuShown = false
        sheet = .symbolDetails
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
        Task { show(await readerCtrl.page(containing: result.position)) }
    }

    private func changeSettings(_ change: (inout ReadingSettings) -> Void) {
        change(&settings)
        Task { await showCurrentPage() }
    }

    private func showCurrentPage() async {
        let viewport = requestedViewport
        let settings = settings
        let page = await readerCtrl.currentPage(viewport: viewport, settings: settings)
        guard viewport == requestedViewport, settings == self.settings else { return }
        self.viewport = viewport
        layoutSettings = settings
        shownPage = page
        pages = [page]
        marks = [:]
        loadPages(around: page)
        loadPageTotals()
    }

    private func show(_ page: Page, highlighting mentionIndex: Int? = nil) {
        highlightedMentionIndex = mentionIndex
        shownPage = page
        loadPages(around: page)
        Task { await readerCtrl.pageChanged(to: page) }
    }

    private func loadPages(around page: Page) {
        Task {
            let pages = await readerCtrl.pages(around: page)
            guard shownPage == page else { return }
            self.pages = pages
            await loadMarks()
        }
    }

    private func loadMarks() async {
        var marks: [Int: [Mark]] = [:]
        for page in pages {
            marks[page.number] = try? await refCtrl.marks(
                on: page,
                highlighting: highlightedMentionIndex,
                includingSymbols: layoutSettings.areSymbolsShown
            )
        }
        self.marks = marks
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
