import SwiftUI

/// Search remains available after the inline iPhone search field scrolls away.
struct LibraryFloatingSearchButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "magnifyingglass")
                .font(AppTypography.title2(.regular))
                .foregroundStyle(AppColors.textPrimary)
                .libraryIconFrame()
                .contentShape(.circle)
                .glassEffect(.regular.interactive(), in: .circle)
        }
        .buttonStyle(.plain)
        .libraryControlLabel("Search books", symbol: "magnifyingglass")
    }
}

#Preview("Floating Library Search") {
    LibraryFloatingSearchButton(action: {})
        .padding()
        .background(AppColors.bgPrimary)
        .preferredColorScheme(.dark)
}
