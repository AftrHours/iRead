import SwiftUI

struct BookRowView: View {
    let book: BookRecord
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(spacing: 4) {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 60, height: 80)

                // Progress Bar constrained to thumbnail width
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.black.opacity(0.18))
                        Capsule()
                            .fill(Color.gray)
                            .frame(width: geometry.size.width * CGFloat(min(max(book.progress, 0), 1)))
                    }
                }
                .frame(width: 60, height: 4)
            }
            
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

#Preview("Row Item") {
    BookRowView(book: BookRecord(
        id: UUID(),
        title: "Project Hail Mary",
        author: "Andy Weir",
        isContinueReading: false,
        progress: 0.4
    ))
    .padding()
}
