import SwiftUI

/// The note after returning to the page being read, for a moment.
struct ReferredToast: View {
    let text: String

    var body: some View {
        Text(text)
            .font(AppTypography.footnote(.regular))
            .foregroundStyle(AppColors.textPrimary)
            .frame(width: 149, height: 34)
            .background(AppColors.popoverQuoteIconBg.opacity(0.3), in: .capsule)
            .padding(.vertical, 8)
            .transition(.opacity)
    }
}

#Preview("Toast") {
    ReferredToast(text: "Returned to page 66")
}
