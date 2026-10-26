import SwiftUI

struct RefCardView: View {
    let card: ReaderVM.ReferenceCard
    let onJumpTapped: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Earlier Mention")
                .font(.headline)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 8) {
                Text(card.name)
                    .font(.title2.bold())
                Text(card.location)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(card.quote)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
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
    }
}
