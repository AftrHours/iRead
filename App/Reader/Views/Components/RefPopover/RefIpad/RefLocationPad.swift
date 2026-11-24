import SwiftUI

struct RefLocationPad: View {
    let location: String

    var body: some View {
        Text(location)
            .font(AppTypography.caption1(.semibold))
            .textCase(.uppercase)
            .lineLimit(1)
            .foregroundStyle(AppColors.popoverLocationText)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(AppColors.popoverLocationBg, in: .rect(cornerRadius: 8))
    }
}

#Preview {
    RefLocationPad(location: "Chapter 1 • Page 8")
        .padding()
        .background(AppColors.popoverBg)
}
