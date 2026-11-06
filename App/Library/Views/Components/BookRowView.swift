import SwiftUI

struct BookRowView<MenuButton: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let book: BookRecord
    let cover: UIImage?
    let menu: MenuButton

    var body: some View {
        HStack(spacing: 16) {
            VStack(spacing: 4) {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(width: 60, height: 60 / bookCoverAspectRatio)
                    .overlay {
                        if let cover {
                            Image(uiImage: cover)
                                .resizable()
                                .scaledToFill()
                        }
                    }
                    .clipped()
                    .clipShape(.rect(cornerRadius: 4))
                ProgressBar(progress: book.progress)
                    .frame(width: 60)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(book.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LibraryPalette.primaryText)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
                Text(book.author)
                    .font(.caption)
                    .foregroundStyle(LibraryPalette.secondaryText)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
            }

            Spacer()

            menu
        }
    }
}

#Preview("Row Item") {
    BookRowView(book: BookRecord(
        id: UUID(),
        title: "Project Hail Mary",
        author: "Andy Weir",
        isContinueReading: false,
        progress: 0.4
    ), cover: nil, menu: Image(systemName: "ellipsis"))
    .padding()
}
