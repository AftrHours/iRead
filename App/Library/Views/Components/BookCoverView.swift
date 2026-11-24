import SwiftUI

/// Shared cover rendering for grid cards and list rows.
struct BookCoverView: View {
    static let aspectRatio: CGFloat = 2 / 3
    let image: UIImage?
    var bookID: UUID?
    @Environment(\.libraryImportDestination) private var destination

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
            .opacity(isDestination ? 0 : 1)
            .anchorPreference(key: LibraryImportCoverAnchor.self, value: .bounds) {
                isDestination ? $0 : nil
            }
    }
    private var isDestination: Bool { bookID != nil && bookID == destination }
}

extension EnvironmentValues {
    @Entry var libraryImportDestination: UUID?
}

struct LibraryImportCoverAnchor: PreferenceKey {
    static var defaultValue: Anchor<CGRect>? { nil }

    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}

#Preview("Book Cover") {
    BookCoverView(image: nil)
        .frame(width: 171)
        .padding()
}
