import SwiftUI

struct RefHeaderPhone: View {
    let location: String

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image("quotationIcon")
                .resizable()
                .frame(width: 47, height: 47)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Mentioned earlier")
                    .font(AppTypography.subheadline(.semibold))
                    .foregroundStyle(AppColors.textPrimary)
                Spacer(minLength: 0)
                RefLocationPhone(location: location)
            }
            .frame(height: 47)
        }
    }
}

#Preview {
    RefHeaderPhone(location: "Chapter 1 • Page 8")
        .padding()
        .background(AppColors.popoverBg)
}
