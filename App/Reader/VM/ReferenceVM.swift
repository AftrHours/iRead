import Foundation
import Observation

@MainActor
@Observable
final class ReferenceVM {
    enum Card: Identifiable {
        case reference(ReferenceCard)
        case symbol(SymbolCard)

        var id: String {
            switch self {
            case .reference(let card): "reference \(card.underlineID)"
            case .symbol(let card): "symbol \(card.entity.id)"
            }
        }
    }

    struct ReferenceCard {
        let underlineID: String
        let phrase: String
        let location: String
        let quote: String
    }

    private(set) var marks: [Int: [Mark]] = [:]
    private(set) var card: Card?
    private(set) var cardAnchor = CGRect.zero
    private(set) var canReturn = false
    private(set) var toastText: String?
    private(set) var chapterEntities: [Entity] = []
    private(set) var editedSymbols: [String: SymbolStyle] = [:]

    @ObservationIgnored var onShowPage: (Page, String?) -> Void = { _, _ in }
    @ObservationIgnored var onEditSymbol: (Entity) -> Void = { _ in }

    private var shownPage: Page?
    private var loadedPages: [Page] = []
    private var areSymbolsShown = false
    private var highlightedUnderlineID: String?
    private var highlightedSearchResult: SearchResult?
    private var isFollowingAnalysis = false
    private var underlinedChapter: Int?
    private var underlineTask: Task<Void, Never>?
    private var entityToEditAfterCard: Entity?
    private let refCtrl: RefCtrl
    private let readerStateCtrl: ReaderStateCtrl
    private let readerCtrl: ReaderCtrl

    init(refCtrl: RefCtrl, readerStateCtrl: ReaderStateCtrl, readerCtrl: ReaderCtrl) {
        self.refCtrl = refCtrl
        self.readerStateCtrl = readerStateCtrl
        self.readerCtrl = readerCtrl
    }

    func onAppear() {
        followAnalysis()
    }

    func appForegrounded() {
        followAnalysis()
        if let shownPage, underlinedChapter == nil { followUnderlines(from: shownPage) }
    }

    private func followAnalysis() {
        guard !isFollowingAnalysis else { return }
        isFollowingAnalysis = true
        Task {
            await refCtrl.startAnalysis()
            for await _ in await refCtrl.analysisUpdates() {
                await loadMarks()
            }
            await loadMarks()
            isFollowingAnalysis = false
        }
    }

    /// Underlines the shown page's chapter, starting at that page, and redraws the marks as underlines are found.
    private func followUnderlines(from page: Page) {
        underlinedChapter = page.chapterIndex
        underlineTask?.cancel()
        underlineTask = Task {
            guard let updates = try? await refCtrl.underlineUpdates(from: page) else { return }
            for await _ in updates {
                await loadMarks()
            }
        }
    }

    func appBackgrounded() {
        Task { await refCtrl.stopAnalysis() }
        underlineTask?.cancel()
        underlinedChapter = nil
    }

    func bookOpened() async {
        await readerStateCtrl.load()
        canReturn = await readerStateCtrl.hasReturnPosition()
        editedSymbols = await readerStateCtrl.editedSymbols()
    }

    func symbolStyle(for entity: Entity) -> SymbolStyle {
        SymbolPalette.style(for: entity, edited: editedSymbols)
    }

    func update(shownPage: Page?, loadedPages: [Page], areSymbolsShown: Bool) {
        self.shownPage = shownPage
        self.loadedPages = loadedPages
        self.areSymbolsShown = areSymbolsShown
        if let shownPage, shownPage.chapterIndex != underlinedChapter {
            followUnderlines(from: shownPage)
        }
    }

    func pageShown(highlighting underlineID: String?, searchResult: SearchResult? = nil) {
        highlightedUnderlineID = underlineID
        highlightedSearchResult = searchResult
    }

    func layoutChanged() {
        marks = [:]
    }

    func markTapped(_ mark: Mark, at anchor: CGRect) {
        Task {
            switch mark.kind {
            case .underline(let id):
                guard let underline = try? await refCtrl.underline(withID: id) else { return }
                let passagePage = await readerCtrl.page(containing: underline.passage.start)
                let chapterTitles = await readerCtrl.chapterTitles()
                cardAnchor = anchor
                card = .reference(ReferenceCard(
                    underlineID: id,
                    phrase: underline.phrase,
                    location: "\(chapterTitles[passagePage.chapterIndex]) • Page \(passagePage.number)",
                    quote: "“\(underline.passage.text)”"
                ))
            case .symbol(_, _, let mentionIndex):
                guard let symbolCard = try? await refCtrl.symbolCard(forMention: mentionIndex) else { return }
                cardAnchor = anchor
                card = .symbol(symbolCard)
            case .highlight:
                break
            }
        }
    }

    func cardDismissed() {
        card = nil
    }

    func chapterSymbolsShown() {
        chapterEntities = []
        guard let chapterIndex = shownPage?.chapterIndex else { return }
        Task { chapterEntities = (try? await refCtrl.entities(inChapter: chapterIndex)) ?? [] }
    }

    func editSymbolTapped(_ entity: Entity) {
        guard card != nil else {
            onEditSymbol(entity)
            return
        }
        // iOS drops a sheet presented while the card is still closing, so wait for cardDisappeared.
        entityToEditAfterCard = entity
        card = nil
    }

    func cardDisappeared() {
        guard let entity = entityToEditAfterCard else { return }
        entityToEditAfterCard = nil
        onEditSymbol(entity)
    }

    func symbolSaved(_ style: SymbolStyle, for entity: Entity) {
        editedSymbols[entity.id] = style
        Task {
            await readerStateCtrl.saveSymbol(style, forEntity: entity.id)
            await loadMarks()
        }
    }

    func jumpToPassageTapped() {
        guard case .reference(let referenceCard) = card, let shownPage else { return }
        card = nil
        canReturn = true
        Task {
            await readerStateCtrl.saveReturnPosition(await readerCtrl.startPosition(of: shownPage))
            guard let underline = try? await refCtrl.underline(withID: referenceCard.underlineID) else { return }
            onShowPage(await readerCtrl.page(containing: underline.passage.start), referenceCard.underlineID)
        }
    }

    func returnToReadingTapped() {
        canReturn = false
        Task {
            guard let position = await readerStateCtrl.returnPosition(), let page = await readerCtrl.page(ifValid: position) else { return }
            await readerStateCtrl.clearReturnPosition()
            onShowPage(page, nil)
            toastText = "Returned to page \(page.number)"
            try? await Task.sleep(for: .seconds(2))
            toastText = nil
        }
    }

    func returnDismissed() {
        canReturn = false
        highlightedUnderlineID = nil
        Task {
            await readerStateCtrl.clearReturnPosition()
            await loadMarks()
        }
    }

    #if DEBUG
    func makeUnderlineDebugVM() -> UnderlineDebugVM {
        UnderlineDebugVM(refCtrl: refCtrl, chapterIndex: shownPage?.chapterIndex)
    }
    #endif

    func loadMarks() async {
        let pages = loadedPages
        var marks: [Int: [Mark]] = [:]
        for page in pages {
            var pageMarks = (try? await refCtrl.marks(
                on: page,
                highlighting: highlightedUnderlineID,
                includingSymbols: areSymbolsShown,
                editedSymbols: editedSymbols
            )) ?? []
            if let searchResult = highlightedSearchResult,
               let range = await readerCtrl.range(from: searchResult.position, length: searchResult.length, on: page) {
                // Same highlight as a jumped-to passage.
                pageMarks.append(Mark(range: range, kind: .highlight))
            }
            marks[page.number] = pageMarks
        }
        guard pages == loadedPages else { return }
        self.marks = marks
    }
}
