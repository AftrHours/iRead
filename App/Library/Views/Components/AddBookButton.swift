import SwiftUI

/// Dedicated add-book control, shared by the header and empty state.
struct AddBookButton: View {
    var size: CGFloat = 48
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(.title3, weight: .semibold))
                .foregroundStyle(.black)
                .libraryIconFrame(size)
                .contentShape(.circle)
                .glassEffect(.regular.tint(AppColors.actionPrimary).interactive())
        }
        .buttonStyle(.plain)
        .libraryControlLabel("Import EPUB", symbol: "plus")
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
