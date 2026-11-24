import SwiftUI

struct BookRowView<MenuButton: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.isBrowsingLibraryOnPhone) private var isPhoneBrowse
    @Environment(\.isSelectingLibraryOnPhone) private var isPhoneSelection
    let item: LibraryBookItemVM
    let menu: MenuButton
    let onTap: () -> Void

    private let coverWidth: CGFloat = 64

    var body: some View {
        let selectionCenterOffset: CGFloat = isPhoneSelection ? 3.5 : 0
        HStack(spacing: isPhoneBrowse ? 4 : 16) {
            LibraryBookButton(item: item, action: onTap) {
                HStack(spacing: 16) {
                    VStack(spacing: isPhoneBrowse || isPhoneSelection ? 8 : 6) {
                        BookCoverView(image: item.cover)
                            .frame(width: coverWidth, height: coverWidth / BookCoverView.aspectRatio)
                            .clipShape(.rect(cornerRadius: 4))
                        ProgressBar(progress: item.progress, style: .list)
                            .frame(width: coverWidth)
                    }
                    .scaleEffect(isPhoneSelection && !item.isSelected ? 0.95 : 1)
                    .alignmentGuide(VerticalAlignment.center) { dimensions in
                        dimensions[VerticalAlignment.center] - selectionCenterOffset
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
