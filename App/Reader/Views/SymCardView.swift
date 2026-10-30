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
            }
        }
        .padding(28)
        .frame(width: 520)
        .presentationCompactAdaptation(.popover)
        .presentationBackground(Color(.systemBackground))
    }
}
