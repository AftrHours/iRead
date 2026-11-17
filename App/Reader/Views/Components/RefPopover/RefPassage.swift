import SwiftUI

/// The earlier passage the underline refers to, in a tinted box.
struct RefPassage: View {
    let quote: String

    var body: some View {
        Text(quote)
            .fixedSize(horizontal: false, vertical: true)
            .font(.body)
            .foregroundStyle(AppColors.popoverQuoteText)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.popoverBg, in: .rect(cornerRadius: 8))
    }
}

#Preview {
    RefPassage(quote: "…‘Curly black hair, brown skin, big black eyes, handsome nose, fine teeth, small hands and feet, "
        + "taller than I am, very polite, for a boy, and altogether jolly. Wonder how old he is?’…")
        .frame(width: 520)
        .padding()
        .background(AppColors.popoverBg)
}
