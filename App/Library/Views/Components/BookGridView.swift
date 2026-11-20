import SwiftUI

struct BookGridView<MenuButton: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let item: LibraryBookItemVM
    let menu: MenuButton
    let onTap: () -> Void

    var body: some View {
        LibraryBookButton(item: item, action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                BookCoverView(image: item.cover)
                ProgressBar(progress: item.progress)
                    .padding(.top, 10)
                HStack(spacing: 4) {
                    bookDetails
                        .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
                    if !item.showsSelection {
                        Color.clear
                            .libraryIconFrame(44)
                            .anchorPreference(key: BookMenuCenter.self, value: .center) { $0 }
                    }
                }
                .padding(.top, 9)
                .padding(.horizontal, 12)
                .padding(.bottom, 15)
            }
            .background(AppColors.cardBg)
            .clipShape(.rect(cornerRadius: 16))
        }
        // Keep the menu outside the book button, aligned to its slot in the metadata row.
        .overlayPreferenceValue(BookMenuCenter.self) { center in
            if let center {
                GeometryReader { geometry in
                    menu.fixedSize().position(geometry[center])
                }
            }
        }
        .overlay(alignment: .topTrailing) { LibrarySelectionBadge(item: item) }
    }

    private var bookDetails: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.title)
                .font(AppTypography.caption1(.semibold))
                .foregroundStyle(AppColors.cardTextPrimary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
            Text(item.author)
                .font(AppTypography.caption1(.medium))
                .foregroundStyle(AppColors.cardTextSecondary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
        }
    }
}

private struct BookMenuCenter: PreferenceKey {
    static var defaultValue: Anchor<CGPoint>? { nil }

    static func reduce(value: inout Anchor<CGPoint>?, nextValue: () -> Anchor<CGPoint>?) {
        value = nextValue() ?? value
    }
}

private struct BookGridPreview: View {
    private let item = LibraryBookItemVM(book: BookRecord.samples[0].book)

    var body: some View {
        BookGridView(item: item, menu: BookMenu(item: item, style: .card, onFinished: {}, onRename: {}, onRemove: {}), onTap: {})
            .frame(width: 171)
            .padding()
            .background(AppColors.bgPrimary)
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

#Preview("Book Card — Wrapping Text") {
    BookGridPreview()
        .environment(\.dynamicTypeSize, .accessibility2)
}
