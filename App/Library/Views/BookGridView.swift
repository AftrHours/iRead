import SwiftUI

/// Cover width to height in the library design (171 × 234 pt).
let bookCoverAspectRatio: CGFloat = 171 / 234

struct BookGridView<MenuButton: View>: View {
    let book: BookRecord
    let cover: UIImage?
    let menu: MenuButton

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(Color(.systemGray5))
                .aspectRatio(bookCoverAspectRatio, contentMode: .fit)
                // Cropped from the bottom, so the title at the top of most covers stays visible.
                .overlay(alignment: .top) {
                    if let cover {
                        Image(uiImage: cover)
                            .resizable()
                            .scaledToFill()
                    }
                }
                .clipped()

            ProgressBar(progress: book.progress)
                .padding(.top, 10)

            HStack(alignment: .center, spacing: 4) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(book.title)
                        .font(.body.weight(.medium))
                    Text(book.author)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .lineLimit(1)
                Spacer(minLength: 0)
                menu
            }
            .padding(.top, 6)
        }
    }
}

/// The thin reading-progress bar under a cover.
struct ProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color(.systemGray5))
                Rectangle()
                    .fill(Color(.systemGray2))
                    .frame(width: geometry.size.width * min(max(progress, 0), 1))
            }
        }
        .frame(height: 6)
        .accessibilityElement()
        .accessibilityLabel("\(Int((min(max(progress, 0), 1) * 100).rounded()))% read")
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
