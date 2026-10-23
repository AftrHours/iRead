// Views/BookGridView.swift
import SwiftUI

struct BookGridView: View {
    let book: BookRecord
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(spacing: 4) {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .aspectRatio(3/4, contentMode: .fit)

                // Progress Bar spanning the cover width
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.black.opacity(0.18))
                        Capsule()
                            .fill(Color.gray)
                            .frame(width: geometry.size.width * CGFloat(min(max(book.progress, 0), 1)))
                    }
                }
                .frame(height: 4)
            }
            
            HStack {
                VStack(alignment: .leading) {
                    Text(book.title)
                        .font(.headline)
                    Text(book.author)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                Spacer()
                Image(systemName: "ellipsis")
                    .foregroundColor(.gray)
            }
        }
    }
}

#Preview("Grid Item") {
    BookGridView(book: BookRecord(
        id: UUID(),
        title: "The Martian",
        author: "Andy Weir",
        isContinueReading: true,
        progress: 0.4
    ))
    .frame(width: 160)
    .padding()
}
