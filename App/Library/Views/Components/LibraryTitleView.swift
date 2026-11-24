import SwiftUI

/// Shared Library heading, placed in the header or scrolling content by the screen layout.
struct LibraryTitleView: View {
    var body: some View {
        Text("Library")
            .accessibilityAddTraits(.isHeader)
            .font(AppTypography.largeTitle(.bold))
            .foregroundStyle(AppColors.textPrimary)
    }
}

#Preview("Library Title") {
    LibraryTitleView()
        .padding()
        .background(AppColors.bgPrimary)
}
