import SwiftUI

struct RefHeaderPad: View {
    let location: String

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Image("quotationIcon")
                .resizable()
                .frame(width: 68, height: 68)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Mentioned earlier")
                    .font(AppTypography.title2(.bold))
                    .foregroundStyle(AppColors.textPrimary)
                Spacer(minLength: 0)
                RefLocationPad(location: location)
            }
            .frame(height: 68)
        }
    }
}

#Preview {
    RefHeaderPad(location: "Chapter 1 • Page 8")
        .padding()
        .background(AppColors.popoverBg)
}
