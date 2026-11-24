import SwiftUI

struct BookGridView<MenuButton: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.isBrowsingLibraryOnPhone) private var isPhoneBrowse
    @Environment(\.isSelectingLibraryOnPhone) private var isPhoneSelection
    @Environment(\.colorScheme) private var colorScheme
    let item: LibraryBookItemVM
    var isSearchResult = false
    let menu: MenuButton
    let onTap: () -> Void

    var body: some View {
        let selected = item.showsSelection && item.isSelected
        let scale: CGFloat = selected ? 1.05 : 1
        let shadow = colorScheme == .dark ? Color.white.opacity(0.65) : Color(white: 26.0 / 255).opacity(0.5)
        GridCardSlot(scale: scale) {
            card
                .scaleEffect(scale)
                .shadow(color: selected ? shadow : .clear, radius: colorScheme == .dark ? 8 : 20)
        }
    }

    private var card: some View {
        LibraryBookButton(item: item, action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                BookCoverView(image: item.cover)
                    .overlay(.black.opacity(item.showsSelection && !item.isSelected ? 0.5 : 0))
                ProgressBar(progress: item.progress)
                    .opacity(item.showsSelection && !item.isSelected ? 0.5 : 1)
                    .padding(.top, isPhoneSelection ? 11 : (isPhoneBrowse ? 12 : 10))
                HStack(spacing: isPhoneBrowse ? 0 : 4) {
                    bookDetails
                        .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
                    if !item.showsSelection {
                        Color.clear
                            .libraryIconFrame(44)
                            .frame(height: 0)
                            .anchorPreference(key: BookMenuCenter.self, value: .center) { $0 }
                    }
                }
                .padding(.top, isPhoneSelection ? 7 : 9)
                .padding(.leading, 12)
                .padding(.trailing, isPhoneBrowse ? 0 : 12)
                .padding(.bottom, isPhoneSelection ? 11 : (isPhoneBrowse ? 12 : 15))
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
        .overlay(alignment: .topTrailing) {
            LibrarySelectionBadge(item: item)
                .dynamicTypeSize(...LibraryLayout.maximumIconSize)
                .padding(8)
        }
    }

    private var bookDetails: some View {
        VStack(alignment: .leading, spacing: isPhoneBrowse ? 4 : 6) {
            Text(item.title)
                .font(isSearchResult || isPhoneBrowse ? AppTypography.subheadline(.semibold) : AppTypography.footnote(.semibold))
                .foregroundStyle(AppColors.cardTextPrimary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
            Text(item.author)
                .font(isSearchResult || isPhoneBrowse ? AppTypography.footnote(.medium) : AppTypography.caption1(.medium))
                .foregroundStyle(AppColors.cardTextSecondary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
        }
    }
}

/// Include the selected card’s visual height when the grid positions the next row.
private struct GridCardSlot: Layout {
    var scale: CGFloat

    var animatableData: CGFloat {
        get { scale }
        set { scale = newValue }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let card = subviews.first else { return .zero }
        let size = card.sizeThatFits(ProposedViewSize(width: proposal.width, height: nil))
        return CGSize(width: size.width, height: size.height * scale)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: CGPoint(x: bounds.midX, y: bounds.midY), anchor: .center,
                              proposal: ProposedViewSize(width: bounds.width, height: nil))
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
