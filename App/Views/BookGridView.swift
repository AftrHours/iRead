// Views/BookGridView.swift
import SwiftUI

struct BookGridView: View {
    let book: BookRecord
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .aspectRatio(3/4, contentMode: .fit)
            
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
        isContinueReading: true
    ))
    .frame(width: 160)
    .padding()
}
