import SwiftUI

struct RefHeaderPad: View {
    let location: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: "quote.opening")
                .font(.title2.weight(.black))
                .foregroundStyle(AppColors.popoverQuoteIcon)
                .readerIconFrame(47)
                .background(AppColors.popoverQuoteIconBg, in: .rect(cornerRadius: 5.6))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text("Mentioned earlier")
                    .font(AppTypography.subheadline(.semibold   ))
                    .foregroundStyle(AppColors.textPrimary)
                Spacer(minLength: 0)
                RefLocation(location: location)
            }
            .frame(height: 47)
        }
    }
}

#Preview {
    RefHeaderPad(location: "Chapter 1 • Page 8")
        .padding()
        .background(AppColors.popoverBg)
}
