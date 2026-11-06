import SwiftUI

struct RefCardView: View {
    let card: ReferenceVM.ReferenceCard
    let ratingVM: RatingVM
    let onJumpTapped: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Explained Earlier")
                .font(.headline)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 8) {
                Text(card.phrase)
                    .font(.title2.bold())
                Text(card.location)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(card.quote)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                thumb(.up)
                thumb(.down)
                Spacer()
                Button("Jump to Passage", systemImage: "arrow.up.backward", action: onJumpTapped)
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .controlSize(.large)
            }
        }
        .padding(28)
        .frame(width: 520)
        .presentationCompactAdaptation(.popover)
        .presentationBackground(Color(.systemBackground))
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
        .foregroundStyle(isChosen ? Color.accentColor : .secondary)
        .accessibilityLabel(verdict == .up ? "Helpful Passage" : "Unhelpful Passage")
        .accessibilityAddTraits(isChosen ? .isSelected : [])
    }
}
