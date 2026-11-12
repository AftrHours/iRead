import SwiftUI

struct LibraryEmptyStateView: View {
    let libVM: LibVM
    let layout: LibraryLayout

    var body: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 12)
            if let illustration = libVM.emptyStateImage {
                Image(uiImage: illustration)
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
                    .frame(width: layout.emptyImageSize.width, height: layout.emptyImageSize.height)
                    .accessibilityHidden(true)
            }
            Text(libVM.emptyStateTitle)
                .font(AppTypography.headline())
                .foregroundStyle(AppColors.textPrimary)
            Text(libVM.emptyStateMessage)
                .font(AppTypography.subheadline())
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
            if libVM.showsImportInEmptyState {
                AddBookButton(size: 40, action: libVM.importTapped)
                    .padding(.top, 4)
            }
            Spacer(minLength: 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("Empty Library") {
    LibraryEmptyStateView(libVM: PreviewFixtures.emptyLibraryVM(), layout: LibraryLayout())
        .background(AppColors.backgroundPrimary)
}

#Preview("No Search Results") {
    LibView(libVM: PreviewFixtures.searchResultsVM())
}
