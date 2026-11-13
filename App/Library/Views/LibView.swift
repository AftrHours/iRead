import SwiftUI

/// Composes the Library screen. State transitions and user actions belong to LibVM.
struct LibView: View {
    @Bindable var libVM: LibVM
    @FocusState private var isSearchFocused: Bool
    private var layout: LibraryLayout { LibraryLayout(isSearching: libVM.isSearchActive) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LibraryHeaderView(libVM: libVM, layout: layout, searchFocus: $isSearchFocused)

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
                LibraryBookCollection(
                    items: libVM.bookItems,
                    viewMode: libVM.viewMode,
                    layout: layout,
                    onBookTapped: libVM.bookTapped,
                    onFinished: libVM.finishedToggled,
                    onRename: libVM.renameTapped,
                    onRemove: libVM.removeTapped
                )
            }
        }
        .task { await libVM.onAppear() }
        .onChange(of: isSearchFocused) { _, focused in libVM.searchFocusChanged(focused) }
        .onChange(of: libVM.isSearchActive) { _, active in isSearchFocused = active }
        .animation(layout.isPad ? nil : .easeInOut(duration: 0.2), value: libVM.isSearchActive)
        .background(AppColors.backgroundPrimary.ignoresSafeArea())
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
