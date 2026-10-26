import SwiftUI

struct SymCardView: View {
    let card: SymbolCard
    let onEditTapped: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(card.entity.name, systemImage: card.entity.symbolName)
                .font(.title3.bold())
            if let appearance = card.appearance {
                Text("“\(appearance.text)”")
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Spacer()
                Button("Edit Symbol", action: onEditTapped)
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
