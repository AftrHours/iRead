import SwiftUI

enum RefPopoverPadKnobs {
    static let size = CGSize(width: 534, height: 300)
}

struct RefPopoverPad: View {
    let card: ReferenceVM.ReferenceCard
    let verdict: Verdict?
    let onVerdictTapped: (Verdict) -> Void
    let onJumpTapped: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            RefHeaderPad(location: card.location)
            RefPassagePad(quote: card.quote)
            RefActionPad(verdict: verdict, onVerdictTapped: onVerdictTapped, onJumpTapped: onJumpTapped)
        }
        .padding(24)
        .frame(width: 534, height: 300 )
    }
}

#Preview {
    RefPopoverPad(
        card: ReferenceVM.ReferenceCard.preview,
        verdict: nil,
        onVerdictTapped: { _ in },
        onJumpTapped: {}
    )
    .background(AppColors.cardBg)
}
