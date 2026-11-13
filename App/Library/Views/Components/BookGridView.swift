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

            metadata
                .padding(.top, 9)
                .padding(.horizontal, 12)
                .padding(.bottom, 15)
        }
        .background(AppColors.cardBackground)
        .clipShape(.rect(cornerRadius: 16))
    }

    @ViewBuilder
    private var metadata: some View {
        if dynamicTypeSize.isAccessibilitySize {
            HStack(spacing: 4) {
                bookDetails
                Spacer(minLength: 0)
                menu
            }
        } else {
            bookDetails
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .overlay(alignment: .trailing) { menu }
        }
    }

    private var bookDetails: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.title)
                .font(AppTypography.caption1(.semibold))
                .foregroundStyle(AppColors.cardTextPrimary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
            Text(item.author)
                .font(AppTypography.caption1(.medium))
                .foregroundStyle(AppColors.cardTextSecondary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
        }
    }
}

private struct BookGridPreview: View {
    private let item = LibraryBookItemVM(book: BookRecord.samples[0].book)

    var body: some View {
        BookGridView(item: item, menu: BookMenu(item: item, style: .card, onFinished: {}, onRename: {}, onRemove: {}))
            .frame(width: 171, height: 340)
            .padding()
            .background(AppColors.backgroundPrimary)
    }
}

#Preview("Book Card — Light") {
    BookGridPreview()
        .preferredColorScheme(.light)
}

#Preview("Book Card — Dark") {
    BookGridPreview()
        .preferredColorScheme(.dark)
}
