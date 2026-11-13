import SwiftUI

struct LibraryHeaderView: View {
    let libVM: LibVM
    let layout: LibraryLayout
    let searchFocus: FocusState<Bool>.Binding

    private var showsFocusedPhoneSearch: Bool { !layout.isPad && libVM.isSearchActive }
    private var showsEmptyPhoneLibrary: Bool { !layout.isPad && libVM.isLibraryEmpty && !libVM.isSearchActive }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            topBar
                .padding(.horizontal, showsFocusedPhoneSearch ? 8 : showsEmptyPhoneLibrary ? 16 : 20)
                .padding(.top, showsFocusedPhoneSearch || showsEmptyPhoneLibrary ? 0 : 8)
                .padding(.bottom, showsFocusedPhoneSearch ? 16 : 0)

            if !showsFocusedPhoneSearch {
                if layout.isPad {
                    libraryTitle
                        .padding(.horizontal, layout.sideMargin)
                        .padding(.top, 10)
                        .padding(.bottom, 12)
                } else if showsEmptyPhoneLibrary {
                    libraryTitle
                        .padding(.horizontal, layout.sideMargin)
                        .padding(.top, 0.5)
                } else {
                    LibrarySearchBar(libVM: libVM, focus: searchFocus)
                        .padding(.horizontal, layout.sideMargin)
                        .padding(.top, 12)
                        .padding(.bottom, 20)
                }
            }
        }
    }

    private var topBar: some View {
        Group {
            if libVM.isSelectionMode {
                HStack(spacing: 12) { selectionControls }
            } else if showsFocusedPhoneSearch {
                LibraryActiveSearchHeader(libVM: libVM, searchFocus: searchFocus)
            } else {
                HStack(spacing: 12) {
                    if !layout.isPad && !showsEmptyPhoneLibrary { libraryTitle }
                    Spacer()
                    if layout.isPad {
                        padSearchControls
                        LibraryMainMenu(libVM: libVM)
                        AddBookButton(action: libVM.importTapped)
                    } else if showsEmptyPhoneLibrary {
                        AddBookButton(size: 48, iconFont: .system(size: 19, weight: .semibold), action: libVM.importTapped)
                        LibraryMainMenu(libVM: libVM, iconFont: AppTypography.title2(.medium))
                    } else {
                        AddBookButton(action: libVM.importTapped)
                        LibraryMainMenu(libVM: libVM)
                    }
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
            LibrarySearchBar(libVM: libVM, focus: searchFocus, style: .pad, focusesOnContainerTap: false)
                .frame(width: 280)
            searchCloseButton(size: 36, foreground: AppColors.textSecondary)
        } else {
            searchButton(size: 44)
        }
    }

    private func searchButton(size: CGFloat) -> some View {
        Button(action: libVM.searchTapped) {
            Image(systemName: "magnifyingglass")
                .font(AppTypography.callout())
                .foregroundStyle(AppColors.textPrimary)
                .frame(width: size, height: size)
                .glassEffect(.regular.interactive(), in: .circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Search books")
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
