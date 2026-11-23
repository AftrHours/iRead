import SwiftUI

struct LibraryHeaderView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let libVM: LibVM
    let layout: LibraryLayout
    let searchFocus: FocusState<Bool>.Binding
    var includesPhoneSearchField = true

    private var showsFocusedPhoneSearch: Bool { !layout.isPad && libVM.isSearchActive }
    private var showsEmptyPhoneLibrary: Bool { !layout.isPad && libVM.isLibraryEmpty && !libVM.isSearchActive }

    private var topBarInsets: EdgeInsets {
        if libVM.isSelectionMode && !showsFocusedPhoneSearch {
            let margin = layout.sideMargin
            return EdgeInsets(top: 0, leading: margin, bottom: 0, trailing: margin)
        }
        if layout.isPad {
            return EdgeInsets(top: 8, leading: 12, bottom: 0, trailing: 12)
        }
        if showsFocusedPhoneSearch {
            return EdgeInsets(top: 0, leading: 8, bottom: 20, trailing: 8)
        }
        if showsEmptyPhoneLibrary {
            return EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
        }
        if !layout.isPad && libVM.showsScrolledLibraryControls {
            // Preserve the bar's total height to avoid shifting the scroll threshold.
            return EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16)
        }
        return EdgeInsets(top: 0, leading: layout.sideMargin, bottom: 0, trailing: layout.sideMargin)
    }

    private var showsSeparatePadSearch: Bool {
        layout.isPad && libVM.isSearchActive && !libVM.isSelectionMode && horizontalSizeClass == .compact
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            topBar
                .padding(topBarInsets)

            if showsSeparatePadSearch {
                HStack { padSearchControls }
                    .padding(.horizontal, 12)
            }
            if libVM.isSelectionMode && !showsFocusedPhoneSearch {
                HStack {
                    LibrarySearchBar(libVM: libVM, focus: searchFocus, style: libVM.isSearchActive ? .pad : .phone)
                    if libVM.isSearchActive { searchCloseButton }
                }
                .padding(.horizontal, layout.sideMargin)
                .padding(.top, 16)
                .padding(.bottom, 20)
            } else if !layout.isPad && !showsFocusedPhoneSearch {
                if showsEmptyPhoneLibrary {
                    libraryTitle
                        .padding(.horizontal, layout.sideMargin)
                        .padding(.top, 0.5)
                }
                if includesPhoneSearchField && !showsEmptyPhoneLibrary {
                    LibrarySearchBar(libVM: libVM, focus: searchFocus)
                        .padding(.horizontal, layout.sideMargin)
                        .padding(.top, 16)
                        .padding(.bottom, 20)
                }
            }
        }
        .animation(layout.isPad ? nil : .easeInOut(duration: 0.2), value: libVM.showsScrolledLibraryControls)
    }

    private var topBar: some View {
        Group {
            if showsFocusedPhoneSearch {
                LibraryActiveSearchHeader(libVM: libVM, searchFocus: searchFocus)
            } else if libVM.isSelectionMode {
                selectionControls
            } else {
                HStack(spacing: 12) {
                    if !layout.isPad && !showsEmptyPhoneLibrary && !libVM.showsScrolledLibraryControls && !dynamicTypeSize.isAccessibilitySize { libraryTitle }
                    Spacer()
                    if layout.isPad {
                        if !showsSeparatePadSearch { padSearchControls }
                        LibraryMainMenu(libVM: libVM)
                        AddBookButton(action: libVM.importTapped)
                    } else {
                        AddBookButton(action: libVM.importTapped)
                        if libVM.showsScrolledLibraryControls {
                            LibraryPhoneMenuGroup(libVM: libVM)
                        } else {
                            LibraryMainMenu(libVM: libVM, iconFont: showsEmptyPhoneLibrary ? AppTypography.title2(.medium) : AppTypography.body(.medium))
                        }
                    }
                }
            }
        }
        .frame(minHeight: 48)
    }

    private var libraryTitle: some View {
        LibraryTitleView()
    }

    private var selectionControls: some View {
        HStack {
            libraryTitle
            Spacer()
            Button(action: libVM.selectionModeDismissed) {
                Image(systemName: "checkmark")
                    .font(AppTypography.title2(.medium))
                    .libraryIconFrame()
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppColors.textPrimary)
            .libraryControlLabel("Done selecting books", symbol: "checkmark")
            .accessibilityValue(libVM.selectionTitle)
        }
    }

    @ViewBuilder
    private var padSearchControls: some View {
        if libVM.isSearchActive {
            LibrarySearchBar(libVM: libVM, focus: searchFocus, style: .pad, focusesOnContainerTap: false)
                .frame(maxWidth: 280)
            searchCloseButton
        } else {
            LibraryFloatingSearchButton(action: libVM.searchTapped)
        }
    }

    private var searchCloseButton: some View {
        Button(action: libVM.searchDismissed) {
            Image(systemName: "xmark")
                .font(AppTypography.callout(.semibold))
                .foregroundStyle(AppColors.textSecondary)
                .libraryIconFrame(44)
                .glassEffect(.regular, in: .circle)
        }
        .buttonStyle(.plain)
        .libraryControlLabel("Close search", symbol: "xmark")
    }
}

#Preview("Library Header") {
    LibView(libVM: PreviewFixtures.libraryVM())
}
