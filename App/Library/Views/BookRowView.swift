import SwiftUI

struct BookRowView<MenuButton: View>: View {
    let book: BookRecord
    let cover: UIImage?
    let menu: MenuButton

    var body: some View {
        HStack(spacing: 16) {
            VStack(spacing: 4) {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(width: 60, height: 60 / bookCoverAspectRatio)
                    .overlay(alignment: .top) {
                        if let cover {
                            Image(uiImage: cover)
                                .resizable()
                                .scaledToFill()
                        }
                    }
                    .clipped()
                ProgressBar(progress: book.progress)
                    .frame(width: 60)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(book.title)
                    .font(.body.weight(.medium))
                Text(book.author)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
