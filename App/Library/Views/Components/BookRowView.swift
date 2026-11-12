import SwiftUI

struct BookRowView<MenuButton: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let item: LibraryBookItemVM
    let menu: MenuButton

    var body: some View {
        HStack(spacing: 16) {
            VStack(spacing: 6) {
                BookCoverView(image: item.cover)
                    .frame(width: 60, height: 60 / BookCoverView.aspectRatio)
                    .clipShape(.rect(cornerRadius: 4))
                ProgressBar(progress: item.progress, style: .list)
                    .frame(width: 60)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(AppTypography.subheadline(.semibold))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
                Text(item.author)
                    .font(AppTypography.footnote())
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
            }

            Spacer()

            menu
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
    )), menu: Image(systemName: "ellipsis"))
    .padding()
}
