import SwiftUI

/// The card shown when an underline is tapped: the iPhone's or the iPad's, and the parts they share, the accessibility label,
/// the popover's look and the question about sharing ratings. Takes plain values and closures, so it previews without any VM.
struct RefPopover: View {
    let card: ReferenceVM.ReferenceCard

    @Environment(\.dynamicTypeSize) private var textSize
    @Environment(\.dismiss) private var dismiss
    let isPad: Bool
    let verdict: Verdict?
    let isAskingToShare: Bool
    let onVerdictTapped: (Verdict) -> Void
    let onSharingChosen: (Bool) -> Void
    let onJumpTapped: () -> Void

    var body: some View {
        Group {
            if textSize > .large {
                NavigationStack {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(card.location).font(.subheadline)
                            Text(card.quote).font(AppTypography.body()).fixedSize(horizontal: false, vertical: true)
                            RefActionPhone(verdict: verdict, onVerdictTapped: onVerdictTapped, onJumpTapped: onJumpTapped)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                    }
                    .navigationTitle("Mentioned earlier")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                    }
                }
            } else if isPad {
                RefPopoverPad(card: card, verdict: verdict, onVerdictTapped: onVerdictTapped, onJumpTapped: onJumpTapped)
            } else {
                RefPopoverPhone(card: card, verdict: verdict, onVerdictTapped: onVerdictTapped, onJumpTapped: onJumpTapped)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Mentioned earlier: \(card.phrase)")
        .presentationCompactAdaptation(textSize > .large ? .automatic : .popover)
        .presentationBackground(AppColors.popoverBg)
        .alert("Share Your Ratings?", isPresented: Binding(get: { isAskingToShare }, set: { _ in })) {
            Button("Share") { onSharingChosen(true) }
            Button("Don't Share", role: .cancel) { onSharingChosen(false) }
        } message: {
            Text("Ratings help the developers improve underlines. Each rating sends the underlined sentence and its passage, "
                 + "without your name. To stop later, contact us through the privacy policy.")
        }
    }
}

extension ReferenceVM.ReferenceCard {
    /// A card for previews.
    static let preview = ReferenceVM.ReferenceCard(
        underlineID: "preview",
        phrase: "Mother",
        location: "Chapter 1 • Page 8",
        quote: "…‘Curly black hair, brown skin, big black eyes, handsome nose, fine teeth, small hands and feet taller than I am, very polite, for a boy, and altogether jolly. Wonder how old he is?’…"
    )
}

#Preview("Ref Popover iPad – Popover") {
    @Previewable @State var isShown = true
    Text("Mother")
        .underline(pattern: .dot)
        .onTapGesture { isShown = true }
        .popover(isPresented: $isShown) {
            RefPopover(
                card: .preview,
                isPad: true,
                verdict: .up,
                isAskingToShare: false,
                onVerdictTapped: { _ in },
                onSharingChosen: { _ in },
                onJumpTapped: {}
            )
        }
}

/// As in the reader: a popover with its arrow pointing at the underline.
#Preview("Ref Popover iPhone – Popover") {
    @Previewable @State var isShown = true
    Text("Mother")
        .underline(pattern: .dot)
        .onTapGesture { isShown = true }
        .popover(isPresented: $isShown) {
            RefPopover(
                card: .preview,
                isPad: false,
                verdict: .up,
                isAskingToShare: false,
                onVerdictTapped: { _ in },
                onSharingChosen: { _ in },
                onJumpTapped: {}
            )
        }
}
