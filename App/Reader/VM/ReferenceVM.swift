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

    @ObservationIgnored var onShowPage: (Page, String?) -> Void = { _, _ in }

    private var shownPage: Page?
    private var loadedPages: [Page] = []
    private var highlightedUnderlineID: String?
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

    func pageShown(highlighting underlineID: String?, searchResult: SearchResult? = nil) {
        if underlineID == nil { jumpedPassageText = nil }
        highlightedUnderlineID = underlineID
        highlightedSearchResult = searchResult
    }

    func layoutChanged() {
        marks = [:]
    }

    func markTapped(_ mark: Mark, at anchor: CGRect) {
        guard case .underline(let id) = mark.kind else { return }
        passageDismissed()
        Task {
            guard let underline = try? await refCtrl.underline(withID: id) else { return }
            let passagePage = await readerCtrl.page(containing: underline.reference.start)
            let chapterTitles = await readerCtrl.chapterTitles()
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
        highlightedUnderlineID = nil
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
        cardDismissed()
        jumpToPassage(ofUnderline: referenceCard.underlineID)
    }

    /// Used by the reference card and the character list.
    func jumpToPassage(ofUnderline underlineID: String) {
        guard let shownPage else { return }
        Task {
            await readerStateCtrl.saveReturnPosition(await readerCtrl.startPosition(of: shownPage))
            await refreshReturnPage()
            guard let underline = try? await refCtrl.underline(withID: underlineID) else { return }
            let destination = await readerCtrl.page(containing: underline.reference.start)
            jumpedPassageText = underline.reference.text
            returnPrompt = .canReturn
            onShowPage(destination, underlineID)
        }
    }

    func returnToReadingTapped() {
        returnPrompt = .none
        Task {
            guard let position = await readerStateCtrl.returnPosition(), let page = await readerCtrl.page(ifValid: position) else { return }
            await readerStateCtrl.clearReturnPosition()
            returnPageNumber = nil
            onShowPage(page, nil)
            let message = "Returned to page \(page.number)"
            returnPrompt = .returned(message: message)
            try? await Task.sleep(for: .seconds(2))
            // Not if a new jump has asked for the choice meanwhile.
            if returnPrompt == .returned(message: message) { returnPrompt = .none }
        }
    }

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
