import SwiftUI

/// Static sample passage and jump card shown during the onboarding introduction.
struct OnboardingReferencePreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("The Last Carriage")
                .font(.headline)
                .foregroundStyle(LibraryPalette.primaryText)
            Text("At dusk, the carriage rolled past the old house, its familiar lanterns glowing in the rain.")
                .font(.body)
                .foregroundStyle(LibraryPalette.primaryText)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
                .padding(16)
                .background(LibraryPalette.progressTrack.opacity(0.45), in: .rect(cornerRadius: 14))
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "quote.opening")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(LibraryPalette.addButton, in: .rect(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 6) {
                    Text("Earlier Mention")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(LibraryPalette.primaryText)
                    Text("Let’s revisit where it all began.")
                        .font(.caption)
                        .foregroundStyle(LibraryPalette.secondaryText)
                    Button("Jump to Passage", systemImage: "arrow.uturn.backward") {}
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                        .tint(LibraryPalette.secondaryText)
                        .padding(.top, 4)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .background(LibraryPalette.card, in: .rect(cornerRadius: 16))
            .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
        }
        .padding(20)
        .background(LibraryPalette.card, in: .rect(cornerRadius: 22))
    }
}

#Preview("Reference Preview Card") {
    OnboardingReferencePreview()
        .padding()
        .background(LibraryPalette.page)
}
