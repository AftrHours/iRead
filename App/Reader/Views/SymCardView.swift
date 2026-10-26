import SwiftUI

struct SymCardView: View {
    let entity: Entity
    let style: SymbolStyle
    let onEditTapped: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text(entity.name)
            } icon: {
                Image(systemName: style.systemName)
                    .foregroundStyle(Color(SymbolPalette.color(at: style.colorIndex)))
            }
            .font(.title3.bold())
            Text(entity.summary)
                .fixedSize(horizontal: false, vertical: true)
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
