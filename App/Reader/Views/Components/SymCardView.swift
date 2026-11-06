import SwiftUI

struct SymCardView: View {
    let card: SymbolCard
    let style: SymbolStyle
    let onEditTapped: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text(card.entity.name)
            } icon: {
                Image(systemName: style.systemName)
                    .foregroundStyle(Color(SymbolPalette.color(at: style.colorIndex)))
            }
            .font(.title3.bold())
            if let appearance = card.appearance {
                Text("“\(appearance.text)”")
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(LibraryPalette.progressTrack.opacity(0.42), in: .rect(cornerRadius: 12))
            } else {
                Text("\(card.entity.name) hasn't been described yet.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Spacer()
                Button("Edit Symbol", action: onEditTapped)
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .controlSize(.large)
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
