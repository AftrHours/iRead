import SwiftUI

struct LibrarySelectionBadge: View {
    let item: LibraryBookItemVM

    @ScaledMetric(relativeTo: .body) private var diameter: CGFloat = 24

    var body: some View {
        if item.showsSelection {
            Image(systemName: item.selectionSymbol)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: diameter, height: diameter)
                .symbolRenderingMode(.palette)
                .foregroundStyle(item.isSelected ? AppColors.bgPrimary : AppColors.textSecondary, AppColors.textPrimary)
                .contentTransition(.opacity)
                .accessibilityHidden(true)
                .allowsHitTesting(false)
        }
    }
}

#Preview("Selected Book Badge") {
    LibrarySelectionBadge(item: LibraryBookItemVM(book: BookRecord.samples[0].book, showsSelection: true, isSelected: true))
}
