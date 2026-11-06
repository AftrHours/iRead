import SwiftUI

struct RefCardView: View {
    let card: ReaderVM.ReferenceCard
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
    }
}
