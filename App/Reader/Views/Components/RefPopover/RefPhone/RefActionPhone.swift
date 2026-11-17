import SwiftUI

/// Bottom of the reference card: thumbs up and down to rate the underline, and Jump to Passage.
/// Takes the chosen verdict and actions only, so it previews without a RatingVM.
struct RefActionPhone: View {
    /// The thumb the reader picked, filled in; nil when the underline isn't rated yet.
    let verdict: Verdict?
    let onVerdictTapped: (Verdict) -> Void
    let onJumpTapped: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            thumb(.up)
            thumb(.down)
            Spacer(minLength: 8)
            Button(action: onJumpTapped) {
                Label("Jump to Passage", systemImage: "arrow.up.left")
                    .font(AppTypography.footnote(.regular))
                    .lineLimit(1)
                    .foregroundStyle(AppColors.actionPrimaryText)
                    .frame(width: 145, height: 34)
                    .background(AppColors.actionPrimary, in: .capsule)
                    .padding(.vertical, 5)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
    }

    private func thumb(_ thumbVerdict: Verdict) -> some View {
        let isChosen = verdict == thumbVerdict
        let symbol = thumbVerdict == .up ? "hand.thumbsup" : "hand.thumbsdown"
        return Button {
            onVerdictTapped(thumbVerdict)
        } label: {
            Image(systemName: isChosen ? "\(symbol).fill" : symbol)
                .font(AppTypography.title2(.semibold))
                .frame(width: 44, height: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .foregroundStyle(AppColors.popoverFeedbackIcon)
        .accessibilityLabel(thumbVerdict == .up ? "Helpful Passage" : "Unhelpful Passage")
        .accessibilityAddTraits(isChosen ? .isSelected : [])
    }
}

#Preview {
    @Previewable @State var verdict: Verdict?
    RefActionPhone(
        verdict: verdict,
        onVerdictTapped: { verdict = verdict == $0 ? nil : $0 },
        onJumpTapped: { print("Jump ditekan") }
    )
    .frame(width: 50)
    .padding()
    .background(AppColors.popoverBg)
}
