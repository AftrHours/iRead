import SwiftUI

/// The card shown when an underline is tapped. Takes plain values and closures, so it previews without any VM.
struct RefPopover: View {
    let card: ReferenceVM.ReferenceCard
    let verdict: Verdict?
    let isAskingToShare: Bool
    let onVerdictTapped: (Verdict) -> Void
    let onSharingChosen: (Bool) -> Void
    let onJumpTapped: () -> Void
    private var cardWidth: CGFloat { UIDevice.current.userInterfaceIdiom == .pad ? 480 : 340 }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            RefHeader(location: card.location)
            RefQuote(quote: card.quote)
            RefAction(verdict: verdict, onVerdictTapped: onVerdictTapped, onJumpTapped: onJumpTapped)
        }
        .padding(24)
        .frame(width: cardWidth)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Mentioned earlier: \(card.phrase)")
        .presentationCompactAdaptation(.popover)
        .presentationBackground(RefPalette.card)
        // The alert sits here, not on the page: a page can't present an alert while this popover is open.
        .alert("Share Your Ratings?", isPresented: Binding(get: { isAskingToShare }, set: { _ in })) {
            Button("Share") { onSharingChosen(true) }
            Button("Don't Share", role: .cancel) { onSharingChosen(false) }
        } message: {
            Text("Ratings help the developers improve underlines. Each rating sends the underlined sentence and its passage, "
                 + "without your name. You can change this in the reader menu.")
        }
    }
}

private let previewCard = ReferenceVM.ReferenceCard(
    underlineID: "preview",
    phrase: "Mother",
    location: "Chapter 1 • Page 8",
    quote: "…‘Curly black hair, brown skin, big black eyes, handsome nose, fine teeth, small hands and feet, "
        + "taller than I am, very polite, for a boy, and altogether jolly. Wonder how old he is?’…"
)

#Preview("Ref Popover") {
    RefPopover(
        card: previewCard,
        verdict: nil,
        isAskingToShare: false,
        onVerdictTapped: { _ in },
        onSharingChosen: { _ in },
        onJumpTapped: {}
    )
    .padding()
}

/// As in the reader: a popover with its arrow pointing at the underline.
#Preview("Ref Popover – Popover") {
    @Previewable @State var isShown = true
    Text("Mother")
        .underline(pattern: .dot)
        .onTapGesture { isShown = true }
        .popover(isPresented: $isShown) {
            RefPopover(
                card: previewCard,
                verdict: .up,
                isAskingToShare: false,
                onVerdictTapped: { _ in },
                onSharingChosen: { _ in },
                onJumpTapped: {}
            )
        }
}
