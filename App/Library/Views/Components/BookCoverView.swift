import SwiftUI

/// Shared cover rendering for grid cards and list rows.
struct BookCoverView: View {
    static let aspectRatio: CGFloat = 2 / 3
    let image: UIImage?

    var body: some View {
        Rectangle()
            .fill(AppColors.menuTextMuted.opacity(0.16))
            .aspectRatio(Self.aspectRatio, contentMode: .fit)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
            }
            .clipped()
    }
}

#Preview("Book Cover") {
    BookCoverView(image: nil)
        .frame(width: 171)
        .padding()
}
