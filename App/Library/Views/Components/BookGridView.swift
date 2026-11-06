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
                .fill(Color(.systemGray5))
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
                .padding(.top, 10)
                .padding(.horizontal, 10)

            HStack(alignment: .center, spacing: 4) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(book.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(LibraryPalette.primaryText)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                    Text(book.author)
                        .font(.caption)
                        .foregroundStyle(LibraryPalette.secondaryText)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                }
                Spacer(minLength: 0)
                menu
            }
            .padding(.top, 4)
            .padding(.horizontal, 10)
            .padding(.bottom, 3)
        }
        .background(LibraryPalette.card, in: .rect(cornerRadius: 14))
        .clipShape(.rect(cornerRadius: 14))
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
