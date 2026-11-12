import SwiftUI

/// Dedicated add-book control, shared by the header and empty state.
struct AddBookButton: View {
    var size: CGFloat = 44
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(AppTypography.title1(.semibold))
                .foregroundStyle(.black)
                .frame(width: size, height: size)
                .contentShape(.circle)
                .glassEffect(.regular.tint(AppColors.actionPrimary).interactive())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Import EPUB")
    }
}

#Preview("Add Book Buttons") {
    HStack(spacing: 16) {
        AddBookButton(action: {})
        AddBookButton(size: 40, action: {})
    }
    .padding()
    .background(LibraryPalette.page)
}
