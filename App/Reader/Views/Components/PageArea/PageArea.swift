import SwiftUI

struct PageArea: View {
    let readerVM: ReaderVM
    /// Space between the screen edge and the text on each side, as a share of the page's width,
    /// so it suits an iPhone and an iPad alike. The page itself still fills the width.
    let textMarginRatio: CGFloat
    private var referenceVM: ReferenceVM { readerVM.referenceVM }
    private var readerSettingsVM: ReaderSettingsVM { readerVM.readerSettingsVM }
    /// Room the reference popover needs below an underline. About the tallest card (a long quote on an iPhone), plus a margin.
    private static let popoverHeight: CGFloat = 400

    var body: some View {
        GeometryReader { proxy in
            let horizontalMargin = (proxy.size.width * textMarginRatio).rounded()
            let viewport = Viewport(size: proxy.size, horizontalMargin: horizontalMargin)
            Group {
                if let shownPage = readerVM.shownPage {
                    PageTurnView(
                        pages: readerVM.pages,
                        shownPage: shownPage,
                        settings: readerSettingsVM.layoutSettings,
                        horizontalMargin: horizontalMargin,
                        marks: referenceVM.marks,
                        onPageChanged: { readerVM.pageChanged($0) },
                        onCenterTapped: { readerVM.pageCenterTapped() },
                        onMarkTapped: { referenceVM.markTapped($0, at: $1) }
                    )
                    .id(readerSettingsVM.layoutSettings.pageTurnStyle)
                    .popover(
                        item: Binding(get: { referenceVM.card }, set: { _ in referenceVM.cardDismissed() }),
                        attachmentAnchor: .rect(.rect(referenceVM.cardAnchor)),
                        // Below the underline when the card fits there, else above it. SwiftUI only takes one fixed
                        // edge, or nil to let the system pick the roomiest side, which puts the card above mid-page underlines.
                        arrowEdge: proxy.size.height - referenceVM.cardAnchor.maxY >= Self.popoverHeight ? .top : .bottom
                    ) { referenceCard in
                        RefPopover(
                            card: referenceCard,
                            verdict: readerVM.ratingVM.verdict,
                            isAskingToShare: readerVM.ratingVM.isAskingToShare,
                            onVerdictTapped: readerVM.ratingVM.verdictTapped,
                            onSharingChosen: readerVM.ratingVM.sharingChosen,
                            onJumpTapped: referenceVM.jumpToPassageTapped
                        )
                        // Reads this underline's saved rating each time the card opens.
                        .task(id: referenceCard.underlineID) { await readerVM.ratingVM.cardShown(underlineID: referenceCard.underlineID) }
                    }
                } else if readerVM.hasFailedToOpen {
                    ContentUnavailableView("Can't Open Book", systemImage: "book.closed")
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .task { await readerVM.onAppear(viewport: viewport) }
            .onChange(of: viewport) { _, viewport in readerVM.viewportChanged(viewport) }
        }
    }
}


#Preview("Page Area") {
    let book = BookRecord.samples.first { $0.book.title == "Little Women" }?.book ?? BookRecord.samples[0].book
    PageArea(readerVM: AppContainer.forPreviews().makeReaderVM(book: book), textMarginRatio: 0.095)
}

