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
            case .reference(let card): "reference \(card.mentionIndex)"
            case .symbol(let card): "symbol \(card.entity.id)"
            }
        }
    }

    struct ReferenceCard {
        let mentionIndex: Int
        let name: String
        let location: String
        let quote: String
    }

    private(set) var marks: [Int: [Mark]] = [:]
    private(set) var card: Card?
    private(set) var cardAnchor = CGRect.zero
    private(set) var canReturn = false
    private(set) var toastText: String?
    #if DEBUG
    private(set) var isEngineRunning = true
    #endif

    @ObservationIgnored var onShowPage: (Page, Int?) -> Void = { _, _ in }
    @ObservationIgnored var onEditSymbol: () -> Void = {}

    private var shownPage: Page?
    private var loadedPages: [Page] = []
    private var areSymbolsShown = false
    private var highlightedMentionIndex: Int?
    private var isFollowingAnalysis = false
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
            #if DEBUG
            isEngineRunning = false
            #endif
        }
    }

    func appBackgrounded() {
        Task { await refCtrl.stopAnalysis() }
    }

    func bookOpened() async {
        await readerStateCtrl.load()
        canReturn = await readerStateCtrl.hasReturnPosition()
    }

    func update(shownPage: Page?, loadedPages: [Page], areSymbolsShown: Bool) {
        self.shownPage = shownPage
        self.loadedPages = loadedPages
        self.areSymbolsShown = areSymbolsShown
    }

    func pageShown(highlighting mentionIndex: Int?) {
        highlightedMentionIndex = mentionIndex
    }

    func layoutChanged() {
        marks = [:]
    }

    func markTapped(_ mark: Mark, at anchor: CGRect) {
        Task {
            guard let entity = try? await refCtrl.entity(forMention: mark.mentionIndex) else { return }
            cardAnchor = anchor
            guard mark.kind == .underline else {
                guard let symbolCard = try? await refCtrl.symbolCard(forMention: mark.mentionIndex) else { return }
                card = .symbol(symbolCard)
                return
            }
            guard let passage = try? await refCtrl.passage(forMention: mark.mentionIndex) else { return }
            let passagePage = await readerCtrl.page(containing: passage.start)
            let chapterTitles = await readerCtrl.chapterTitles()
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
        onEditSymbol()
    }

    func jumpToPassageTapped() {
        guard case .reference(let referenceCard) = card, let shownPage else { return }
        card = nil
        canReturn = true
        Task {
            await readerStateCtrl.saveReturnPosition(await readerCtrl.startPosition(of: shownPage))
            guard let passage = try? await refCtrl.passage(forMention: referenceCard.mentionIndex) else { return }
            onShowPage(await readerCtrl.page(containing: passage.start), referenceCard.mentionIndex)
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
        highlightedMentionIndex = nil
        Task {
            await readerStateCtrl.clearReturnPosition()
            await loadMarks()
        }
    }

    #if DEBUG
    func makeEngineDebugVM() -> EngineDebugVM {
        EngineDebugVM(refCtrl: refCtrl, page: shownPage)
    }
    #endif

    func loadMarks() async {
        let pages = loadedPages
        var marks: [Int: [Mark]] = [:]
        for page in pages {
            marks[page.number] = try? await refCtrl.marks(
                on: page,
                highlighting: highlightedMentionIndex,
                includingSymbols: areSymbolsShown
            )
        }
        guard pages == loadedPages else { return }
        self.marks = marks
    }
}
