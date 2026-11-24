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

    enum ReturnPrompt: Equatable {
        case none
        /// After a jump: the return button is on.
        case canReturn
        /// After returning, for a moment: "Returned to page 66".
        case returned(message: String)
    }

    private(set) var marks: [Int: [Mark]] = [:]
    private(set) var card: ReferenceCard?
    private(set) var cardAnchor = CGRect.zero
    /// The underline whose card is open, highlighted until the card closes.
    private(set) var selectedUnderlineID: String?
    /// The passage a jump landed on, highlighted with "Mentioned here" until the page is tapped or turned.
    private(set) var jumpedPassageText: String?
    private(set) var returnPrompt = ReturnPrompt.none
    private(set) var returnPageNumber: Int?

    @ObservationIgnored var onShowPage: (Page, ContextPassage?) -> Void = { _, _ in }

    @ObservationIgnored var analytics: ReadingAnalytics?
    private var pendingCard: (id: String, attempt: AnalyticsAttempt)?
    private var cardFlow: String?
    private var shownPage: Page?
    private var loadedPages: [Page] = []
    private var highlightedPassage: ContextPassage?
    private var highlightedSearchResult: SearchResult?
    private var isClosed = false
    private var underlinedChapter: Int?
    private(set) var underlineTask: Task<Void, Never>?
    /// Not private, for ReaderVM's debug sheet.
    let refCtrl: RefCtrl
    private let readerStateCtrl: ReaderStateCtrl
    private let readerCtrl: ReaderCtrl

    init(refCtrl: RefCtrl, readerStateCtrl: ReaderStateCtrl, readerCtrl: ReaderCtrl) {
        self.refCtrl = refCtrl
        self.readerStateCtrl = readerStateCtrl
        self.readerCtrl = readerCtrl
    }

    func appForegrounded() {
        if let shownPage, underlinedChapter == nil { followUnderlines(from: shownPage) }
    }

    /// Underlines the shown page's chapter, starting at that page, and redraws the marks as underlines are found.
    /// Holds `self` weakly, so a closed reader is released while the task winds down.
    private func followUnderlines(from page: Page) {
        guard !isClosed else { return }
        underlinedChapter = page.chapterIndex
        underlineTask?.cancel()
        underlineTask = Task { [weak self, refCtrl] in
            let updates: AsyncStream<Void>
            do {
                updates = try await refCtrl.underlineUpdates(from: page)
            } catch {
                if !Task.isCancelled {
                    self?.analytics?.record(.recoverableError, category: BetaAnalytics.category(error), feature: "underlines")
                }
                return
            }
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
        returnPrompt = await readerStateCtrl.hasReturnPosition() ? .canReturn : .none
    }

    /// Page numbers change when the book is laid out again.
    func refreshReturnPage() async {
        guard let position = await readerStateCtrl.returnPosition() else {
            returnPageNumber = nil
            return
        }
        returnPageNumber = await readerCtrl.page(ifValid: position)?.number
    }

    func update(shownPage: Page?, loadedPages: [Page]) {
        self.shownPage = shownPage
        self.loadedPages = loadedPages
        if let shownPage, shownPage.chapterIndex != underlinedChapter {
            followUnderlines(from: shownPage)
        }
    }

    func pageShown(highlighting passage: ContextPassage?, searchResult: SearchResult? = nil) {
        jumpedPassageText = passage?.text
        highlightedPassage = passage
        highlightedSearchResult = searchResult
    }

    func layoutChanged() {
        marks = [:]
    }

    func markTapped(_ mark: Mark, at anchor: CGRect) {
        guard case .underline(let id) = mark.kind else { return }
        passageDismissed()
        analytics?.activity()
        let attempt = AnalyticsAttempt()
        let origin = shownPage
        pendingCard = (id, attempt)
        Task {
            guard let underline = try? await refCtrl.underline(withID: id) else {
                analytics?.record(.recoverableError, category: "missing_reference", feature: "reference_card")
                return
            }
            guard let passagePage = await readerCtrl.page(ifValid: underline.reference.start) else {
                analytics?.record(.recoverableError, category: "invalid_destination", feature: "reference_card")
                return
            }
            let chapterTitles = await readerCtrl.chapterTitles()
            guard !isClosed, shownPage == origin, pendingCard?.attempt.id == attempt.id else { return }
            cardAnchor = anchor
            selectedUnderlineID = id
            card = ReferenceCard(
                underlineID: id,
                phrase: underline.text,
                location: Self.location(chapterTitle: chapterTitles[passagePage.chapterIndex], page: passagePage.number),
                quote: Self.quoted(underline.reference.text)
            )
        }
    }

    /// "Chapter 2 • Page 19" as in the design. A section without a chapter number, like the contents, keeps its title.
    static func location(chapterTitle: String, page: Int) -> String {
        let chapter = ChapterNumber.from(title: chapterTitle).map { "Chapter \($0)" } ?? chapterTitle
        return "\(chapter) • Page \(page)"
    }

    static func quoted(_ text: String) -> String {
        "…\(text.trimmingCharacters(in: .whitespacesAndNewlines))…"
    }

    func cardAppeared(_ card: ReferenceCard) {
        guard let pendingCard, pendingCard.id == card.id else { return }
        self.pendingCard = nil
        cardFlow = pendingCard.attempt.id
        analytics?.record(.referenceCardOpened, flow: cardFlow, reference: card.id, milliseconds: pendingCard.attempt.milliseconds)
    }

    func cardDismissed() {
        card = nil
        selectedUnderlineID = nil
    }

    var hasPassageHighlight: Bool {
        jumpedPassageText != nil || highlightedSearchResult != nil
    }

    func passageDismissed() {
        guard hasPassageHighlight else { return }
        jumpedPassageText = nil
        highlightedPassage = nil
        highlightedSearchResult = nil
        Task { await loadMarks() }
    }

    /// For the popover's binding: setting it to nil closes the card.
    var presentedCard: ReferenceCard? {
        get { card }
        set { if newValue == nil { cardDismissed() } }
    }

    func jumpToPassageTapped() {
        guard let referenceCard = card else { return }
        let flow = cardFlow
        let attempt = AnalyticsAttempt()
        cardDismissed()
        Task {
            guard let underline = try? await refCtrl.underline(withID: referenceCard.underlineID) else {
                analytics?.record(.recoverableError, category: "invalid_destination", feature: "jump")
                return
            }
            jumpToPassage(underline.reference, flow: flow, reference: referenceCard.id, attempt: attempt)
        }
    }

    /// Used by the reference card and the character list. `flow` ties the jump to the card it came from, for analytics.
    func jumpToPassage(_ passage: ContextPassage, flow cardFlow: String? = nil, reference: String? = nil,
                       attempt: AnalyticsAttempt = AnalyticsAttempt()) {
        guard let shownPage else { return }
        analytics?.activity()
        let flow = cardFlow ?? attempt.id
        Task {
            await readerStateCtrl.saveReturnPosition(await readerCtrl.startPosition(of: shownPage), flow: flow)
            await refreshReturnPage()
            guard let destination = await readerCtrl.page(ifValid: passage.start), !isClosed else {
                analytics?.record(.recoverableError, category: "invalid_destination", feature: "jump")
                return
            }
            analytics?.navigating(.jumpCompleted, to: destination, flow: flow, reference: reference, attempt: attempt)
            pageShown(highlighting: passage)
            returnPrompt = .canReturn
            onShowPage(destination, passage)
        }
    }

    func returnToReadingTapped() {
        returnPrompt = .none
        analytics?.activity()
        let attempt = AnalyticsAttempt()
        Task {
            guard let position = await readerStateCtrl.returnPosition(), let page = await readerCtrl.page(ifValid: position), !isClosed else {
                analytics?.record(.recoverableError, category: "invalid_destination", feature: "return")
                return
            }
            let flow = await readerStateCtrl.returnFlow()
            await readerStateCtrl.clearReturnPosition()
            returnPageNumber = nil
            analytics?.navigating(.returnCompleted, to: page, flow: flow, attempt: attempt)
            onShowPage(page, nil)
            let message = "Returned to page \(page.number)"
            returnPrompt = .returned(message: message)
            try? await Task.sleep(for: .seconds(2))
            // Not if a new jump has turned the return button on meanwhile.
            if returnPrompt == .returned(message: message) { returnPrompt = .none }
        }
    }

    func loadMarks() async {
        let pages = loadedPages
        var marks: [Int: [Mark]] = [:]
        for page in pages {
            var pageMarks = (try? await refCtrl.marks(on: page, highlighting: highlightedPassage)) ?? []
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
