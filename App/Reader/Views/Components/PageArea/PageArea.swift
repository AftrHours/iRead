import SwiftUI

/// The pages, filling the whole screen like Apple Books, so the book and chapter titles and the page label turn with the text.
/// The reader's bars stay on top with only their buttons.
struct PageArea: View {
    let readerVM: ReaderVM
    let textMarginRatio: CGFloat
    /// Where the titles, the text and the page label go, in global coordinates. Measured from the reader's bars,
    /// so the text sits, and paginates, exactly where it did between them.
    let screenFrames: PageFrames
    private var referenceVM: ReferenceVM { readerVM.referenceVM }
    private var readerSettingsVM: ReaderSettingsVM { readerVM.readerSettingsVM }
    /// Room the reference popover needs below an underline. About the tallest card (a long quote on an iPhone), plus a margin.
    private static let popoverHeight: CGFloat = 400

    var body: some View {
        GeometryReader { proxy in
            let frames = screenFrames.relative(to: proxy.frame(in: .global).origin)
            // Nothing until the bars are measured: paginating for an empty page would be wasted.
            if !frames.text.isEmpty {
                pages(frames: frames)
            }
        }
    }

    private func pages(frames: PageFrames) -> some View {
        let horizontalMargin = (frames.text.width * textMarginRatio).rounded()
        let viewport = Viewport(size: frames.text.size, horizontalMargin: horizontalMargin)
        return Group {
            if let shownPage = readerVM.shownPage {
                Group {
                    if readerSettingsVM.layoutSettings.pageTurnStyle == .curl {
                        PageTurnView(
                            pages: readerVM.pages,
                            shownPage: shownPage,
                            settings: readerSettingsVM.layoutSettings,
                            horizontalMargin: horizontalMargin,
                            marks: readerVM.visibleMarks,
                            chrome: readerVM.chrome(for:),
                            frames: frames,
                            onPageChanged: { readerVM.pageChanged($0) },
                            onCenterTapped: { readerVM.pageCenterTapped() },
                            onMarkTapped: { referenceVM.markTapped($0, at: $1) }
                        )
                    } else {
                        PageSlideView(
                            pages: readerVM.pages,
                            shownPage: shownPage,
                            settings: readerSettingsVM.layoutSettings,
                            horizontalMargin: horizontalMargin,
                            marks: readerVM.visibleMarks,
                            chrome: readerVM.chrome(for:),
                            frames: frames,
                            onPageChanged: { readerVM.pageChanged($0) },
                            onCenterTapped: { readerVM.pageCenterTapped() },
                            onMarkTapped: { referenceVM.markTapped($0, at: $1) }
                        )
                    }
                }
                .popover(
                    item: Binding(get: { referenceVM.card }, set: { _ in referenceVM.cardDismissed() }),
                    attachmentAnchor: .rect(.rect(referenceVM.cardAnchor)),
                    // Below the underline when the card fits there, else above it. SwiftUI only takes one fixed
                    // edge, or nil to let the system pick the roomiest side, which puts the card above mid-page underlines.
                    arrowEdge: frames.text.maxY - referenceVM.cardAnchor.maxY >= Self.popoverHeight ? .top : .bottom
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

// No preview of its own: it needs the reader's bars to measure. The Reader preview shows it in place.

