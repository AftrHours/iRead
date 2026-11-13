import SwiftUI

/// Renders the first-book prompt separately from an empty search result.
struct LibraryEmptyStateView: View {
    let libVM: LibVM
    let layout: LibraryLayout

    var body: some View {
        Group {
            if libVM.showsSearchEmptyState {
                emptySearch
            } else {
                emptyLibrary
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyLibrary: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    firstBookContent
                    Spacer(minLength: 0)
                }
                // Reserve lower breathing room to optically center the illustration and prompt.
                .padding(.bottom, layout.emptyLibraryBottomInset)
                .frame(maxWidth: .infinity, minHeight: geometry.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
        }
    }

    private var firstBookContent: some View {
        VStack(spacing: layout.emptyLibraryImageSpacing) {
            illustration(size: layout.emptyLibraryImageSize, offset: layout.emptyLibraryImageOffset)

            VStack(spacing: layout.emptyLibraryButtonSpacing) {
                VStack(spacing: layout.emptyLibraryTextSpacing) {
                    Text(libVM.emptyStateTitle)
                        .font(AppTypography.title3(.semibold))
                        .foregroundStyle(AppColors.textPrimary)
                        .multilineTextAlignment(.center)
                    Text(libVM.emptyStateMessage)
                        .font(AppTypography.subheadline(.medium))
                        .foregroundStyle(AppColors.libraryEmptyMessageText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                AddBookButton(size: 48, iconFont: .system(size: 19, weight: .semibold), action: libVM.importTapped)
            }
        }
        .padding(.horizontal, 16)
    }

    private var emptySearch: some View {
        GeometryReader { geometry in
            ScrollView {
                searchEmptyContent
                    .frame(maxWidth: .infinity, minHeight: geometry.size.height, alignment: .center)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
        }
    }

    private var searchEmptyContent: some View {
        VStack(spacing: layout.emptySearchImageSpacing) {
            illustration(size: layout.emptySearchImageSize)
            VStack(spacing: 8) {
                Text(libVM.emptyStateTitle)
                    .font(AppTypography.title3(.semibold))
                    .foregroundStyle(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text(libVM.emptyStateMessage)
                    .font(AppTypography.subheadline(.medium))
                    .foregroundStyle(AppColors.searchEmptyMessageText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func illustration(size: CGSize, offset: CGFloat = 0) -> some View {
        if let illustration = libVM.emptyStateImage {
            Image(uiImage: illustration)
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(width: size.width, height: size.height)
                .offset(x: offset)
                .accessibilityHidden(true)
        }
    }
}

#Preview("Empty Library — Light") {
    LibView(libVM: PreviewFixtures.emptyLibraryVM())
        .preferredColorScheme(.light)
}

#Preview("Empty Library — Dark") {
    LibView(libVM: PreviewFixtures.emptyLibraryVM())
        .preferredColorScheme(.dark)
}

#Preview("No Search Results — Dark") {
    LibView(libVM: PreviewFixtures.searchResultsVM())
        .preferredColorScheme(.dark)
}

#Preview("No Results — Keyboard Space") {
    LibView(libVM: PreviewFixtures.searchResultsVM())
        // Canvas can omit the software keyboard. Reserve its height above the home indicator.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: 272)
        }
        .preferredColorScheme(.dark)
}

#Preview("No Search Results — Light") {
    LibView(libVM: PreviewFixtures.searchResultsVM())
        .preferredColorScheme(.light)
}
