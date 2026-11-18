import SwiftUI

struct LibraryHeaderView: View {
    let libVM: LibVM
    let layout: LibraryLayout
    let searchFocus: FocusState<Bool>.Binding
    var includesPhoneSearchField = true

    private var showsFocusedPhoneSearch: Bool { !layout.isPad && libVM.isSearchActive }
    private var showsEmptyPhoneLibrary: Bool { !layout.isPad && libVM.isLibraryEmpty && !libVM.isSearchActive }

    private var topBarInsets: EdgeInsets {
        if layout.isPad {
            return EdgeInsets(top: 8, leading: 12, bottom: 0, trailing: 12)
        }
        if showsFocusedPhoneSearch {
            return EdgeInsets(top: 0, leading: 8, bottom: 16, trailing: 8)
        }
        if showsEmptyPhoneLibrary {
            return EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
        }
        if !layout.isPad && libVM.showsScrolledLibraryControls {
            // Preserve the bar's total height to avoid shifting the scroll threshold.
            return EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16)
        }
        return EdgeInsets(top: 8, leading: 20, bottom: 0, trailing: 20)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            topBar
                .padding(topBarInsets)

            if !layout.isPad && !showsFocusedPhoneSearch {
                if showsEmptyPhoneLibrary {
                    libraryTitle
                        .padding(.horizontal, layout.sideMargin)
                        .padding(.top, 0.5)
                } else if includesPhoneSearchField {
                    LibrarySearchBar(libVM: libVM, focus: searchFocus)
                        .padding(.horizontal, layout.sideMargin)
                        .padding(.top, 12)
                        .padding(.bottom, 20)
                }
            }
        }
        .animation(layout.isPad ? nil : .easeInOut(duration: 0.2), value: libVM.showsScrolledLibraryControls)
    }

    private var topBar: some View {
        Group {
            if libVM.isSelectionMode {
                HStack(spacing: 12) { selectionControls }
            } else if showsFocusedPhoneSearch {
                LibraryActiveSearchHeader(libVM: libVM, searchFocus: searchFocus)
            } else {
                HStack(spacing: 12) {
                    if !layout.isPad && !showsEmptyPhoneLibrary && !libVM.showsScrolledLibraryControls { libraryTitle }
                    Spacer()
                    if layout.isPad {
                        padSearchControls
                        LibraryMainMenu(libVM: libVM)
                        AddBookButton(action: libVM.importTapped)
                    } else if libVM.showsScrolledLibraryControls {
                        AddBookButton(action: libVM.importTapped)
                        LibraryPhoneMenuGroup(libVM: libVM)
                    } else if showsEmptyPhoneLibrary {
                        AddBookButton(action: libVM.importTapped)
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
        LibraryTitleView()
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
            searchButton(size: 48)
        }
    }

    private func searchButton(size: CGFloat) -> some View {
        Button(action: libVM.searchTapped) {
            Image(systemName: "magnifyingglass")
                .font(AppTypography.title2(.regular))
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
