import Foundation
import Observation

@MainActor
@Observable
final class ReferenceVM {
    struct ReferenceCard: Identifiable {
        let underlineID: String
        let phrase: String
        let location: String
        let quote: String

        var id: String { underlineID }
    }

    private(set) var marks: [Int: [Mark]] = [:]
    private(set) var card: ReferenceCard?
    private(set) var cardAnchor = CGRect.zero
    private(set) var canReturn = false
    private(set) var toastText: String?
    #if DEBUG
    private(set) var isEngineRunning = false
    #endif

    @ObservationIgnored var onShowPage: (Page, String?) -> Void = { _, _ in }

    private var shownPage: Page?
    private var loadedPages: [Page] = []
    private var highlightedUnderlineID: String?
    private var highlightedSearchResult: SearchResult?
    private var isFollowingUnderlines = false
    private var focusedChapter: Int?
    private let refCtrl: RefCtrl
    private let readerStateCtrl: ReaderStateCtrl
    private let readerCtrl: ReaderCtrl

    init(refCtrl: RefCtrl, readerStateCtrl: ReaderStateCtrl, readerCtrl: ReaderCtrl) {
        self.refCtrl = refCtrl
        self.readerStateCtrl = readerStateCtrl
        self.readerCtrl = readerCtrl
    }

    func appForegrounded() {
        followUnderlines()
    }

    /// Needs the shown page, so the reader's chapter goes first. `update` starts it the first time.
    private func followUnderlines() {
        guard !isFollowingUnderlines, let shownPage else { return }
        isFollowingUnderlines = true
        #if DEBUG
        isEngineRunning = true
        #endif
        Task {
            await refCtrl.startUnderlines(at: await readerCtrl.startPosition(of: shownPage))
            for await _ in await refCtrl.underlineUpdates() {
                await loadMarks()
            }
            await loadMarks()
            isFollowingUnderlines = false
            #if DEBUG
            isEngineRunning = false
            #endif
        }
    }

    func appBackgrounded() {
        Task { await refCtrl.stopUnderlines() }
    }

    func bookOpened() async {
        await readerStateCtrl.load()
        canReturn = await readerStateCtrl.hasReturnPosition()
    }

    func update(shownPage: Page?, loadedPages: [Page]) {
        self.shownPage = shownPage
        self.loadedPages = loadedPages
        guard let shownPage, shownPage.chapterIndex != focusedChapter else { return }
        let isFirstPage = focusedChapter == nil
        focusedChapter = shownPage.chapterIndex
        if isFirstPage {
            followUnderlines()
        } else {
            Task { await refCtrl.focusUnderlines(at: await readerCtrl.startPosition(of: shownPage)) }
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
        guard case .underline(let underlineID) = mark.kind else { return }
        Task {
            guard let reference = try? await refCtrl.reference(forUnderline: underlineID) else { return }
            cardAnchor = anchor
            let passage = reference.passage
            let passagePage = await readerCtrl.page(containing: passage.start)
            let chapterTitles = await readerCtrl.chapterTitles()
            card = ReferenceCard(
                underlineID: underlineID,
                phrase: reference.phrase,
                location: "\(chapterTitles[passagePage.chapterIndex]) • Page \(passagePage.number)",
                quote: "“\(passage.text)”"
            )
        }
    }

    func cardDismissed() {
        card = nil
    }

    func jumpToPassageTapped() {
        guard let referenceCard = card, let shownPage else { return }
        card = nil
        canReturn = true
        Task {
            await readerStateCtrl.saveReturnPosition(await readerCtrl.startPosition(of: shownPage))
            guard let reference = try? await refCtrl.reference(forUnderline: referenceCard.underlineID) else { return }
            onShowPage(await readerCtrl.page(containing: reference.passage.start), referenceCard.underlineID)
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
    func makeEngineDebugVM() -> EngineDebugVM {
        EngineDebugVM(refCtrl: refCtrl, page: shownPage)
    }
    #endif

    func loadMarks() async {
        let pages = loadedPages
        var marks: [Int: [Mark]] = [:]
        for page in pages {
            var pageMarks = (try? await refCtrl.marks(on: page, highlighting: highlightedUnderlineID)) ?? []
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
