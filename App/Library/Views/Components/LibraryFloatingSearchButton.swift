import SwiftUI

/// Search remains available after the inline iPhone search field scrolls away.
struct LibraryFloatingSearchButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "magnifyingglass")
                .font(AppTypography.title2(.regular))
                .foregroundStyle(AppColors.textPrimary)
                .frame(width: 48, height: 48)
                .contentShape(.circle)
                .glassEffect(.regular.interactive(), in: .circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Search books")
    }
}

#Preview("Floating Library Search") {
    LibraryFloatingSearchButton(action: {})
        .padding()
        .background(AppColors.bgPrimary)
        .preferredColorScheme(.dark)
}
