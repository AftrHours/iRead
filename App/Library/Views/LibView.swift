import SwiftUI

/// Composes the Library screen. State transitions and user actions belong to LibVM.
struct LibView: View {
    @Bindable var libVM: LibVM
    @Environment(\.scenePhase) private var scenePhase
    @FocusState private var isSearchFocused: Bool
    private var layout: LibraryLayout { LibraryLayout(isSearching: libVM.isSearchActive) }

    var body: some View {
        libraryContent
        .task { await libVM.onAppear() }
        // Books shared from Apple Books wait in the App Group until the app comes back.
        .onChange(of: scenePhase) { _, scenePhase in
            if scenePhase == .active {
                Task { await libVM.appBecameActive() }
            }
        }
        .onChange(of: isSearchFocused) { _, focused in libVM.searchFocusChanged(focused) }
        .onChange(of: libVM.isSearchActive) { _, active in isSearchFocused = active }
        .animation(layout.isPad ? nil : .easeInOut(duration: 0.2), value: libVM.isSearchActive)
        .background(AppColors.bgPrimary.ignoresSafeArea())
        .background {
            EPUBDocumentPicker(isPresented: $libVM.isImportPickerPresented, onPick: libVM.importPickerCompleted)
        }
        .alert("Do you want to delete this book from iCloud and all your iCloud devices?",
               isPresented: $libVM.isRemoveAlertPresented) {
            Button("Delete Everywhere", role: .destructive, action: libVM.removeConfirmed)
            Button("Cancel", role: .cancel, action: libVM.removeCancelled)
        }
        .alert("Rename Book", isPresented: $libVM.isRenameAlertPresented) {
            TextField("Title", text: $libVM.renameDraft)
            Button("Save", action: libVM.renameConfirmed)
            Button("Cancel", role: .cancel, action: libVM.renameCancelled)
        }
        .alert("Couldn’t import EPUB", isPresented: $libVM.isImportAlertPresented) {
            Button("OK", role: .cancel, action: libVM.dismissImportError)
        } message: {
            Text(libVM.importErrorMessage)
        }
        .alert("Voice Search", isPresented: $libVM.isVoiceSearchAlertPresented) {
            Button("OK", role: .cancel, action: libVM.dismissVoiceSearchError)
        } message: {
            Text(libVM.voiceSearchErrorMessage)
        }
        .alert("Something went wrong", isPresented: $libVM.isBookActionAlertPresented) {
            Button("OK", role: .cancel, action: libVM.dismissBookActionError)
        } message: {
            Text(libVM.bookActionErrorMessage)
        }
    }

    @ViewBuilder
    private var libraryContent: some View {
        if layout.isPad {
            VStack(alignment: .leading, spacing: 0) {
                if libVM.isCollectionEmpty {
                    LibraryTitleView()
                        .padding(.horizontal, layout.sideMargin)
                        .padding(.top, 10)
                        .padding(.bottom, 12)
                    LibraryEmptyStateView(libVM: libVM, layout: layout)
                } else {
                    bookCollection
                }
            }
            .safeAreaBar(edge: .top, spacing: 0) {
                LibraryHeaderView(libVM: libVM, layout: layout, searchFocus: $isSearchFocused)
            }
        } else {
            VStack(alignment: .leading, spacing: 0) {
                if let resultsTitle = libVM.searchResultsTitle {
                    Text(resultsTitle)
                        .font(AppTypography.title3(.semibold))
                        .foregroundStyle(AppColors.textPrimary)
                        .padding(.horizontal, layout.sideMargin)
                        .padding(.bottom, 16)
                }

                if libVM.isCollectionEmpty {
                    LibraryEmptyStateView(libVM: libVM, layout: layout)
                } else {
                    bookCollection
                }
            }
            .safeAreaBar(edge: .top, spacing: 0) {
                LibraryHeaderView(libVM: libVM, layout: layout, searchFocus: $isSearchFocused,
                                  includesPhoneSearchField: libVM.isCollectionEmpty)
            }
            .overlay(alignment: .bottomTrailing) {
                if libVM.showsScrolledLibraryControls {
                    LibraryFloatingSearchButton(action: libVM.searchTapped)
                        .padding(.trailing, 16)
                        .transition(.opacity)
                }
            }
        }
    }

    private var bookCollection: some View {
        LibraryBookCollection(
            items: libVM.bookItems,
            viewMode: libVM.viewMode,
            layout: layout,
            onBookTapped: libVM.bookTapped,
            onFinished: libVM.finishedToggled,
            onRename: libVM.renameTapped,
            onRemove: libVM.removeTapped,
            showsLibraryTitle: layout.isPad,
            resultsTitle: layout.isPad ? libVM.searchResultsTitle : nil,
            onScrolled: { offset in
                if !layout.isPad { libVM.libraryScrolled(to: offset) }
            }
        ) {
            if !layout.isPad && !libVM.isSearchActive {
                LibrarySearchBar(libVM: libVM, focus: $isSearchFocused)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
            }
        }
    }
}

#Preview("Library") {
    LibView(libVM: PreviewFixtures.libraryVM())
}

#Preview("Empty Library") {
    LibView(libVM: PreviewFixtures.emptyLibraryVM())
}

#Preview("No Search Results") {
    LibView(libVM: PreviewFixtures.searchResultsVM())
        .preferredColorScheme(.dark)
}

#Preview("iPad Scrolling Library — Dark") {
    @Previewable @State var libVM = PreviewFixtures.scrollingLibraryVM()
    LibView(libVM: libVM)
        .preferredColorScheme(.dark)
}

#Preview("iPad Scrolling Library — Light") {
    @Previewable @State var libVM = PreviewFixtures.scrollingLibraryVM()
    LibView(libVM: libVM)
        .preferredColorScheme(.light)
}

#Preview("iPhone Scrolling Library — Dark") {
    @Previewable @State var libVM = PreviewFixtures.scrollingLibraryVM()
    LibView(libVM: libVM)
        .preferredColorScheme(.dark)
}

#Preview("iPhone Scrolling Library — Light") {
    @Previewable @State var libVM = PreviewFixtures.scrollingLibraryVM()
    LibView(libVM: libVM)
        .preferredColorScheme(.light)
}
