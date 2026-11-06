import SwiftUI

struct RefCardView: View {
    let card: ReferenceVM.ReferenceCard
    let ratingVM: RatingVM
    let onJumpTapped: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "quote.opening")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(LibraryPalette.addButton, in: .rect(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Earlier Mention")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(LibraryPalette.primaryText)
                    Text(card.phrase)
                        .font(.caption)
                        .foregroundStyle(LibraryPalette.secondaryText)
                        .lineLimit(1)
                }
            }
            Text(card.quote)
                .fixedSize(horizontal: false, vertical: true)
                .font(.subheadline)
                .foregroundStyle(LibraryPalette.primaryText)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(LibraryPalette.progressTrack.opacity(0.42), in: .rect(cornerRadius: 12))
            Text(card.location)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(LibraryPalette.secondaryText)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(LibraryPalette.controlFill.opacity(0.35), in: .capsule)
            HStack {
                thumb(.up)
                thumb(.down)
                Spacer()
                Button("Jump to Passage", systemImage: "arrow.up.backward", action: onJumpTapped)
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .controlSize(.regular)
                    .tint(LibraryPalette.secondaryText)
            }
        }
        .padding(18)
        .frame(maxWidth: 360)
        .background(LibraryPalette.card, in: .rect(cornerRadius: 18))
        .presentationCompactAdaptation(.popover)
        .presentationBackground(LibraryPalette.card)
        .shadow(color: .black.opacity(0.10), radius: 12, y: 5)
        .task(id: card.underlineID) { await ratingVM.cardShown(underlineID: card.underlineID) }
        .alert("Share Your Ratings?", isPresented: Binding(get: { ratingVM.isAskingToShare }, set: { _ in })) {
            Button("Share") { ratingVM.sharingChosen(true) }
            Button("Don't Share", role: .cancel) { ratingVM.sharingChosen(false) }
        } message: {
            Text("Ratings help the developers improve underlines. Each rating sends the underlined sentence and its passage, "
                 + "without your name. You can change this in the reader menu.")
        }
    }

    private func thumb(_ verdict: Verdict) -> some View {
        let isChosen = ratingVM.verdict == verdict
        let symbol = verdict == .up ? "hand.thumbsup" : "hand.thumbsdown"
        return Button {
            ratingVM.verdictTapped(verdict)
        } label: {
            Image(systemName: isChosen ? "\(symbol).fill" : symbol)
                .font(.title3)
                .frame(width: 44, height: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isChosen ? LibraryPalette.primaryText : LibraryPalette.secondaryText)
        .accessibilityLabel(verdict == .up ? "Helpful Passage" : "Unhelpful Passage")
        .accessibilityAddTraits(isChosen ? .isSelected : [])
    }
}
