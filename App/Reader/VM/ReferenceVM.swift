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
        var verdict: Verdict?

        var id: String { underlineID }
    }

    private(set) var marks: [Int: [Mark]] = [:]
    private(set) var card: ReferenceCard?
    private(set) var cardAnchor = CGRect.zero
    private(set) var canReturn = false
    private(set) var toastText: String?
    private(set) var isAskingToShare = false
    private(set) var sharesRatings = false
    /// Checked again when the app comes back, in case the reader signed in in Settings.
    private(set) var cloudAccount: CloudAccount?

    @ObservationIgnored var onShowPage: (Page, String?) -> Void = { _, _ in }

    private var shownPage: Page?
    private var loadedPages: [Page] = []
    private var highlightedUnderlineID: String?
    private var highlightedSearchResult: SearchResult?
    private var isClosed = false
    private var underlinedChapter: Int?
    /// Ratings are saved one after another, so quick taps land in order.
    private var ratingTask: Task<Void, Never>?
    /// Readable so tests can check that closing the reader cancels it.
    private(set) var underlineTask: Task<Void, Never>?
    private let refCtrl: RefCtrl
    private let readerStateCtrl: ReaderStateCtrl
    private let readerCtrl: ReaderCtrl

    init(refCtrl: RefCtrl, readerStateCtrl: ReaderStateCtrl, readerCtrl: ReaderCtrl) {
        self.refCtrl = refCtrl
        self.readerStateCtrl = readerStateCtrl
        self.readerCtrl = readerCtrl
    }

    func appForegrounded() {
        if let shownPage, underlinedChapter == nil { followUnderlines(from: shownPage) }
        checkCloud()
    }

    /// Underlines the shown page's chapter, starting at that page, and redraws the marks as underlines are found.
    /// Holds `self` weakly, so a closed reader is released while the task winds down.
    private func followUnderlines(from page: Page) {
        guard !isClosed else { return }
        underlinedChapter = page.chapterIndex
        underlineTask?.cancel()
        underlineTask = Task { [weak self, refCtrl] in
            guard let updates = try? await refCtrl.underlineUpdates(from: page) else { return }
            for await _ in updates {
                guard let self else { return }
                await loadMarks()
            }
        }
    }

    func appBackgrounded() {
        underlineTask?.cancel()
        underlinedChapter = nil
    }

    /// The reader is closing: stops this book's underlining for good.
    func close() {
        isClosed = true
        underlineTask?.cancel()
        underlinedChapter = nil
    }

    func bookOpened() async {
        await readerStateCtrl.load()
        canReturn = await readerStateCtrl.hasReturnPosition()
        sharesRatings = await refCtrl.sharesRatings() == true
        checkCloud()
    }

    /// In the background, so opening a book doesn't wait for iCloud. Also retries ratings an earlier send missed.
    private func checkCloud() {
        Task { [weak self, refCtrl] in
            let account = await refCtrl.cloudAccount()
            self?.cloudAccount = account
            await refCtrl.sendUnsentRatings()
        }
    }

    func update(shownPage: Page?, loadedPages: [Page]) {
        self.shownPage = shownPage
        self.loadedPages = loadedPages
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
        guard case .underline(let id) = mark.kind else { return }
        Task {
            guard let underline = try? await refCtrl.underline(withID: id) else { return }
            let passagePage = await readerCtrl.page(containing: underline.passage.start)
            let chapterTitles = await readerCtrl.chapterTitles()
            let verdict = try? await refCtrl.verdict(onUnderline: id)
            cardAnchor = anchor
            card = ReferenceCard(
                underlineID: id,
                phrase: underline.phrase,
                location: "\(chapterTitles[passagePage.chapterIndex]) • Page \(passagePage.number)",
                quote: "“\(underline.passage.text)”",
                verdict: verdict
            )
        }
    }

    func cardDismissed() {
        card = nil
    }

    /// Tapping the chosen thumb again takes the rating back. The first rating asks whether to share.
    func verdictTapped(_ verdict: Verdict) {
        guard let shown = card else { return }
        let newVerdict = shown.verdict == verdict ? nil : verdict
        card?.verdict = newVerdict
        ratingTask = Task { [previous = ratingTask, refCtrl] in
            if newVerdict != nil, await refCtrl.sharesRatings() == nil { isAskingToShare = true }
            await previous?.value
            try? await refCtrl.rate(underline: shown.underlineID, newVerdict)
        }
    }

    func sharingChosen(_ shares: Bool) {
        isAskingToShare = false
        sharesRatings = shares
        Task { await refCtrl.setSharesRatings(shares) }
    }

    func jumpToPassageTapped() {
        guard let referenceCard = card, let shownPage else { return }
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
