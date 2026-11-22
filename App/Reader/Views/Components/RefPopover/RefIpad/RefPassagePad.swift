import SwiftUI

/// The earlier passage the underline refers to, in a tinted box.
struct RefPassagePad: View {
    let quote: String

    var body: some View {
        Text(quote)
            .font(AppTypography.body(.medium))
            .lineLimit(4)
            .foregroundStyle(AppColors.popoverPassageText)
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(AppColors.popoverPassageBg, in: .rect(cornerRadius: 8))
    }
}

#Preview {
    RefPassagePad(quote: "…‘Curly black hair, brown skin, big black eyes, handsome nose, fine teeth, small hands and feet, "
        + "taller than I am, very polite, for a boy, and altogether jolly. Wonder how old he is?’…")
        .frame(width: 220, height: 80)
        .padding()
        .background(AppColors.popoverBg)
}
