import SwiftUI

struct LibrarySelectionBadge: View {
    let item: LibraryBookItemVM

    var body: some View {
        if item.showsSelection {
            Image(systemName: item.selectionSymbol)
                .font(AppTypography.title3(.semibold))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, item.isSelected ? AppColors.actionPrimary : AppColors.menuTextMuted)
                .padding(8)
                .dynamicTypeSize(...LibraryLayout.maximumIconSize)
                .accessibilityHidden(true)
                .allowsHitTesting(false)
        }
    }
}

#Preview("Selected Book Badge") {
    LibrarySelectionBadge(item: LibraryBookItemVM(book: BookRecord.samples[0].book, showsSelection: true, isSelected: true))
}
