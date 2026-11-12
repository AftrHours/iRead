import SwiftUI

struct BookGridView<MenuButton: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let item: LibraryBookItemVM
    let menu: MenuButton

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            BookCoverView(image: item.cover)

            ProgressBar(progress: item.progress)
                .padding(.top, 10)

            HStack(alignment: .center, spacing: 4) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(AppTypography.caption1(.semibold))
                        .foregroundStyle(AppColors.cardTextPrimary)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                    Text(item.author)
                        .font(AppTypography.caption2())
                        .foregroundStyle(AppColors.cardTextSecondary)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                }
                Spacer(minLength: 0)
                menu
            }
            .padding(.top, 5)
            .padding(.horizontal, 8)
            .padding(.bottom, 7)
        }
        .background(AppColors.cardBackground, in: .rect(cornerRadius: 18))
        .clipShape(.rect(cornerRadius: 18))
    }
}

#Preview("Grid Item") {
    BookGridView(item: LibraryBookItemVM(book: BookRecord(
        id: UUID(),
        title: "The Martian",
        author: "Andy Weir",
        isContinueReading: true,
        progress: 0.4
    )), menu: Image(systemName: "ellipsis"))
    .frame(width: 171)
    .padding()
}
