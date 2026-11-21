import SwiftUI

/// Where the earlier passage is, as a small chip: CHAPTER • PAGE.
struct RefLocationPhone: View {
    let location: String

    var body: some View {
        Text(location)
            .font(AppTypography.caption2(.medium))
            .textCase(.uppercase)
            .lineLimit(1)
            .foregroundStyle(AppColors.popoverLocationText)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(AppColors.popoverLocationBg, in: .rect(cornerRadius: 5))
    }
}

#Preview {
    RefLocationPhone(location: "Chapter 1 • Page 8")
        .padding()
        .background(AppColors.popoverBg)
}
