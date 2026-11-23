import SwiftUI

struct BookRowView<MenuButton: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let item: LibraryBookItemVM
    let menu: MenuButton
    let onTap: () -> Void

    private let coverWidth: CGFloat = 64

    var body: some View {
        HStack(spacing: 16) {
            LibraryBookButton(item: item, action: onTap) {
                HStack(spacing: 16) {
                    VStack(spacing: 6) {
                        BookCoverView(image: item.cover)
                            .frame(width: coverWidth, height: coverWidth / BookCoverView.aspectRatio)
                            .clipShape(.rect(cornerRadius: 4))
                        ProgressBar(progress: item.progress, style: .list)
                            .frame(width: coverWidth)
                    }
                    .opacity(item.showsSelection && !item.isSelected ? 0.5 : 1)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(AppTypography.body(.semibold))
                            .foregroundStyle(AppColors.textPrimary)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                        Text(item.author)
                            .font(AppTypography.callout())
                            .foregroundStyle(AppColors.textSecondary)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                    }

                    Spacer()

                    LibrarySelectionBadge(item: item)
                        .dynamicTypeSize(...LibraryLayout.maximumIconSize)
                }
            }
            if !item.showsSelection { menu }
        }
    }
}

#Preview("Row Item") {
    BookRowView(item: LibraryBookItemVM(book: BookRecord(
        id: UUID(),
        title: "Project Hail Mary",
        author: "Andy Weir",
        isContinueReading: false,
        progress: 0.4
    )), menu: Image(systemName: "ellipsis"), onTap: {})
    .padding()
}
