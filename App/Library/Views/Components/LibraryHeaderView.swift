import SwiftUI

struct LibraryHeaderView: View {
    let libVM: LibVM
    let layout: LibraryLayout
    let searchFocus: FocusState<Bool>.Binding

    private var showsFocusedPhoneSearch: Bool { !layout.isPad && libVM.isSearchActive }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            topBar
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, showsFocusedPhoneSearch ? 16 : 0)

            if !showsFocusedPhoneSearch {
                if layout.isPad {
                    libraryTitle
                        .padding(.horizontal, layout.sideMargin)
                        .padding(.top, 10)
                        .padding(.bottom, 12)
                }

                if !layout.isPad {
                    LibrarySearchBar(libVM: libVM, focus: searchFocus)
                        .padding(.horizontal, layout.sideMargin)
                        .padding(.top, 12)
                        .padding(.bottom, 20)
                }
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            if libVM.isSelectionMode {
                selectionControls
            } else if showsFocusedPhoneSearch {
                LibrarySearchBar(libVM: libVM, focus: searchFocus)
                    .frame(maxWidth: .infinity)
                searchCloseButton(size: 44, foreground: AppColors.textPrimary)
            } else {
                if !layout.isPad { libraryTitle }
                Spacer()
                if layout.isPad {
                    padSearchControls
                    LibraryMainMenu(libVM: libVM)
                    AddBookButton(action: libVM.importTapped)
                } else {
                    AddBookButton(action: libVM.importTapped)
                    LibraryMainMenu(libVM: libVM)
                }
            }
        }
        .frame(height: 48)
    }

    private var libraryTitle: some View {
        Text("Library")
            .font(AppTypography.largeTitle(.bold))
            .foregroundStyle(AppColors.textPrimary)
    }

    private var selectionControls: some View {
        Group {
            Button("Cancel", action: libVM.selectionModeDismissed)
                .font(AppTypography.callout())
                .foregroundStyle(AppColors.textSecondary)
            Spacer()
            Text(libVM.selectionTitle)
                .font(AppTypography.callout(.semibold))
                .foregroundStyle(AppColors.textPrimary)
            Spacer()
            Button("Done", action: libVM.selectionModeDismissed)
                .font(AppTypography.callout(.semibold))
                .foregroundStyle(AppColors.textSecondary)
        }
    }

    @ViewBuilder
    private var padSearchControls: some View {
        if libVM.isSearchActive {
            LibrarySearchBar(libVM: libVM, focus: searchFocus, focusesOnContainerTap: false)
                .frame(width: 280)
            searchCloseButton(size: 36, foreground: AppColors.textSecondary)
        } else {
            Button(action: libVM.searchTapped) {
                Image(systemName: "magnifyingglass")
                    .font(AppTypography.callout())
                    .foregroundStyle(AppColors.textPrimary)
                    .frame(width: 44, height: 44)
                    .glassEffect(.regular, in: .circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Search books")
        }
    }

    private func searchCloseButton(size: CGFloat, foreground: Color) -> some View {
        Button(action: libVM.searchDismissed) {
            Image(systemName: "xmark")
                .font(AppTypography.callout(.semibold))
                .foregroundStyle(foreground)
                .frame(width: size, height: 44)
                .glassEffect(.regular, in: .circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close search")
    }
}

#Preview("Library Header") {
    LibView(libVM: PreviewFixtures.libraryVM())
}
