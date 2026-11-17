import SwiftUI

enum RefPopoverPhoneKnobs {

    static let size = CGSize(width: 325, height: 204)
}

/// The reference card on an iPhone: 325 × 204, the passage in the room left between the header and the actions.
struct RefPopoverPhone: View {
    let card: ReferenceVM.ReferenceCard
    let verdict: Verdict?
    let onVerdictTapped: (Verdict) -> Void
    let onJumpTapped: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RefHeaderPhone(location: card.location)
            RefPassagePhone(quote: card.quote)
            RefActionPhone(verdict: verdict, onVerdictTapped: onVerdictTapped, onJumpTapped: onJumpTapped)
        }
        .padding(16)
        .frame(width: RefPopoverPhoneKnobs.size.width, height: RefPopoverPhoneKnobs.size.height)
    }
}

#Preview {
    RefPopoverPhone(
        card: ReferenceVM.ReferenceCard.preview,
        verdict: nil,
        onVerdictTapped: { _ in },
        onJumpTapped: {}
    )
    .background(AppColors.cardBg)
}
