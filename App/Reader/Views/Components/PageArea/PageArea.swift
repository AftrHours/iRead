import SwiftUI

/// The pages, filling the whole screen like Apple Books, so the book and chapter titles and the page label turn with the text.
/// The reader's bars stay on top with only their buttons. It renders what `ReaderVM` says and forwards taps: it shows the pager
/// of the chosen style, and hosts the reference card.
struct PageArea: View {
    let readerVM: ReaderVM
    @Bindable var referenceVM: ReferenceVM
    @Environment(\.dynamicTypeSize) private var textSize
    let ratingVM: RatingVM

    var body: some View {
        Group {
            if let content = readerVM.pageContent {
                pages(content)
                    .popover(
                        item: presentedCard(sheet: false),
                        attachmentAnchor: .rect(.rect(referenceVM.cardAnchor)),
                        arrowEdge: readerVM.isCardBelowUnderline ? .top : .bottom
                    ) { referenceCard in
                        cardView(referenceCard)
                    }
                    .sheet(item: presentedCard(sheet: true)) { cardView($0) }
            } else if readerVM.hasFailedToOpen {
                ContentUnavailableView("Can't Open Book", systemImage: "book.closed")
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func presentedCard(sheet: Bool) -> Binding<ReferenceVM.ReferenceCard?> {
        Binding {
            (textSize > .large) == sheet ? referenceVM.presentedCard : nil
        } set: { value in
            if (textSize > .large) == sheet { referenceVM.presentedCard = value }
        }
    }

    private func cardView(_ referenceCard: ReferenceVM.ReferenceCard) -> some View {
        RefPopover(
            card: referenceCard,
            isPad: readerVM.isCardForPad,
            verdict: ratingVM.verdict,
            isAskingToShare: ratingVM.isAskingToShare,
            onVerdictTapped: ratingVM.verdictTapped,
            onSharingChosen: ratingVM.sharingChosen,
            onJumpTapped: referenceVM.jumpToPassageTapped
        )
        // Reads this underline's saved rating each time the card opens.
        .task(id: referenceCard.underlineID) {
            await ratingVM.cardShown(underlineID: referenceCard.underlineID)
        }
    }

    /// Curl on UIPageViewController's own curl; Slide and Fast Fade on our pager.
    @ViewBuilder
    private func pages(_ content: PageContent) -> some View {
        let actions = PageActions(
            onPageChanged: readerVM.pageChanged,
            onCenterTapped: readerVM.pageCenterTapped,
            claimReadingFocus: readerVM.claimReadingFocus,
            onMarkTapped: { referenceVM.markTapped($0, at: $1) }
        )
        if content.settings.pageTurnStyle == .curl {
            PageTurnView(content: content, actions: actions)
        } else {
            PageSlideView(content: content, actions: actions)
        }
    }
}

/// For previews: a sample book opened in a reader, with the screen measured as `ReaderView` does.
struct PagePreview<Content: View>: View {
    @State private var readerVM = PreviewFixtures.readerVM()
    @ViewBuilder let content: (ReaderVM) -> Content

    var body: some View {
        ZStack {
            content(readerVM)
                .ignoresSafeArea()
        }
        .onGeometryChange(for: ScreenGeometry.self) {
            ScreenGeometry(safeSize: $0.size, safeAreaTop: $0.safeAreaInsets.top, safeAreaBottom: $0.safeAreaInsets.bottom)
        } action: {
            readerVM.screenChanged($0)
        }
        .task { await readerVM.onAppear() }
    }
}

#Preview("Page Area") {
    PagePreview { readerVM in
        PageArea(readerVM: readerVM, referenceVM: readerVM.referenceVM, ratingVM: readerVM.ratingVM)
    }
}
