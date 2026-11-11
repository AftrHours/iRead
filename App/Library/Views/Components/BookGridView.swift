import SwiftUI

/// The Hi-Fi library uses portrait covers close to a standard 2:3 book ratio.
let bookCoverAspectRatio: CGFloat = 2 / 3

struct BookGridView<MenuButton: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let book: BookRecord
    let cover: UIImage?
    let menu: MenuButton

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(AppColors.menuTextMuted.opacity(0.16))
                .aspectRatio(bookCoverAspectRatio, contentMode: .fit)
                .overlay {
                    if let cover {
                        Image(uiImage: cover)
                            .resizable()
                            .scaledToFill()
                    }
                }
                .clipped()

            ProgressBar(progress: book.progress)
                .padding(.top, 5)

            HStack(alignment: .center, spacing: 4) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(book.title)
                        .font(AppTypography.caption1(.semibold))
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                    Text(book.author)
                        .font(AppTypography.caption2())
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                }
                Spacer(minLength: 0)
                menu
            }
            .padding(.top, 5)
            .padding(.horizontal, 8)
            .padding(.bottom, 7)
        }
        .background(AppColors.popoverBackground, in: .rect(cornerRadius: 10))
        .clipShape(.rect(cornerRadius: 10))
    }
}

#Preview("Grid Item") {
    BookGridView(book: BookRecord(
        id: UUID(),
        title: "The Martian",
        author: "Andy Weir",
        isContinueReading: true,
        progress: 0.4
    ), cover: nil, menu: Image(systemName: "ellipsis"))
    .frame(width: 171)
    .padding()
}
