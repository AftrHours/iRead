import SwiftUI
import UIKit

struct LibView: View {
    @Bindable var libVM: LibVM
    @Environment(\.scenePhase) private var scenePhase
    @State private var isMainMenuPresented = false
    @State private var isPadSearchExpanded = false
    @FocusState private var isSearchFocused: Bool

    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }
    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: isPad ? 18 : 12, alignment: .top), count: isPad ? 4 : 2)
    }
    private var sideMargin: CGFloat { isPad ? 34 : 16 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            topBar
                .padding(.horizontal, 20)
                .padding(.top, 8)

            Text("Library")
                .font(AppTypography.largeTitle(.bold))
                .foregroundStyle(AppColors.textPrimary)
                .padding(.horizontal, sideMargin)
                .padding(.top, 10)
                .padding(.bottom, 12)

            if !isPad {
                searchBar
                    .padding(.horizontal, sideMargin)
                    .padding(.bottom, 20)
            }

            if libVM.visibleBooks.isEmpty {
                emptyStateView
            } else {
                bookCollection
            }
        }
        .task { await libVM.onAppear() }
        // Books shared from Apple Books wait in the App Group until the app comes back.
        .onChange(of: scenePhase) { _, scenePhase in
            if scenePhase == .active {
                Task { await libVM.appBecameActive() }
            }
        }
        .background(AppColors.backgroundPrimary.ignoresSafeArea())
        .background {
            EPUBDocumentPicker(isPresented: $libVM.isImportPickerPresented) { result in
                libVM.importPickerCompleted(result)
            }
        }
        .alert("Do you want to delete this book from iCloud and all your iCloud devices?",
               isPresented: $libVM.isRemoveAlertPresented) {
            Button("Delete Everywhere", role: .destructive) { libVM.removeConfirmed() }
            Button("Cancel", role: .cancel) { libVM.removeCancelled() }
        }
        .alert("Rename Book", isPresented: $libVM.isRenameAlertPresented) {
            TextField("Title", text: $libVM.renameDraft)
            Button("Save") { libVM.renameConfirmed() }
            Button("Cancel", role: .cancel) { libVM.renameCancelled() }
        }
        .alert("Couldn’t import EPUB", isPresented: $libVM.isImportAlertPresented) {
            Button("OK", role: .cancel) { libVM.dismissImportError() }
        } message: {
            Text(libVM.importError ?? "Please try another EPUB file.")
        }
        .alert("Voice Search", isPresented: $libVM.isVoiceSearchAlertPresented) {
            Button("OK", role: .cancel) { libVM.dismissVoiceSearchError() }
        } message: {
            Text(libVM.voiceSearchError ?? "Voice search is unavailable.")
        }
        .alert("Something went wrong", isPresented: $libVM.isBookActionAlertPresented) {
            Button("OK", role: .cancel) { libVM.dismissBookActionError() }
        } message: {
            Text(libVM.bookActionError ?? "")
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            if libVM.isSelectionMode {
                Button("Cancel") { libVM.selectionModeDismissed() }
                    .font(AppTypography.callout())
                    .foregroundStyle(AppColors.textSecondary)
                Spacer()
                Text("\(libVM.selectedBookIDs.count) Selected")
                    .font(AppTypography.callout(.semibold))
                    .foregroundStyle(AppColors.textPrimary)
                Spacer()
                Button("Done") { libVM.selectionModeDismissed() }
                    .font(AppTypography.callout(.semibold))
                    .foregroundStyle(AppColors.textSecondary)
            } else {
                Spacer()
                if isPad {
                    if isPadSearchExpanded {
                        searchBar
                            .frame(width: 280)
                        Button {
                            isPadSearchExpanded = false
                            isSearchFocused = false
                            libVM.searchText = ""
                        } label: {
                            Image(systemName: "xmark")
                                .font(AppTypography.callout(.semibold))
                                .foregroundStyle(AppColors.textSecondary)
                                .frame(width: 36, height: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Close search")
                    } else {
                        Button {
                            isPadSearchExpanded = true
                            isSearchFocused = true
                        } label: {
                            Image(systemName: "magnifyingglass")
                                .font(AppTypography.callout())
                                .foregroundStyle(AppColors.textPrimary)
                                .frame(width: 44, height: 44)
                                .background(AppColors.settingsControlBackground, in: .circle)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Search books")
                    }
                }
                Button {
                    isMainMenuPresented = true
                    Task { await libVM.refreshCloudAccount() }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(AppTypography.callout(.semibold))
                        .foregroundStyle(AppColors.textPrimary)
                        .frame(width: 44, height: 44)
                        .background(AppColors.settingsControlBackground, in: .circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Library options")
                .popover(isPresented: $isMainMenuPresented, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
                    LibraryMainMenu(libVM: libVM, isPresented: $isMainMenuPresented)
                }

                LibraryIconButton(
                    systemName: "plus",
                    accessibilityLabel: "Import EPUB",
                    fill: AppColors.actionPrimary,
                    foreground: .white,
                    size: 44,
                    action: libVM.importTapped
                )
            }
        }
        .frame(height: 48)
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppColors.textSecondary)
            TextField("Search", text: $libVM.searchText)
                .font(AppTypography.body())
                .foregroundStyle(AppColors.textPrimary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($isSearchFocused)
            Button(action: libVM.voiceSearchTapped) {
                Image(systemName: libVM.isVoiceSearchActive ? "waveform" : "mic")
                    .font(AppTypography.callout())
                    .foregroundStyle(libVM.isVoiceSearchActive ? AppColors.actionPrimary : AppColors.textSecondary)
                    .frame(width: 32, height: 40)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(libVM.isVoiceSearchActive ? "Stop voice search" : "Search by voice")
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(AppColors.settingsControlBackground, in: .capsule)
    }

    private var bookCollection: some View {
        ScrollView {
            Group {
                if libVM.viewMode == .grid {
                    LazyVGrid(columns: gridColumns, spacing: isPad ? 22 : 12) {
                        ForEach(libVM.visibleBooks) { book in
                            BookGridView(
                                book: book,
                                cover: libVM.covers[book.id],
                                menu: BookMenu(book: book, libVM: libVM, isHidden: libVM.isSelectionMode)
                            )
                            .overlay(alignment: .topTrailing) { selectionMark(for: book) }
                            .contentShape(.rect)
                            .onTapGesture { libVM.bookTapped(book) }
                        }
                    }
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(libVM.visibleBooks) { book in
                            BookRowView(
                                book: book,
                                cover: libVM.covers[book.id],
                                menu: BookMenu(book: book, libVM: libVM, isHidden: libVM.isSelectionMode)
                            )
                            .overlay(alignment: .trailing) { selectionMark(for: book) }
                            .contentShape(.rect)
                            .onTapGesture { libVM.bookTapped(book) }
                            Rectangle()
                                .fill(LibraryPalette.divider)
                                .frame(height: 1)
                        }
                    }
                }
            }
            .padding(.horizontal, sideMargin)
            .padding(.bottom, 28)
        }
    }

    @ViewBuilder
    private func selectionMark(for book: BookRecord) -> some View {
        if libVM.isSelectionMode {
            Image(systemName: libVM.selectedBookIDs.contains(book.id) ? "checkmark.circle.fill" : "circle")
                .font(AppTypography.title3(.semibold))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, libVM.selectedBookIDs.contains(book.id) ? AppColors.actionPrimary : AppColors.menuTextMuted)
                .padding(8)
                .accessibilityLabel(libVM.selectedBookIDs.contains(book.id) ? "Selected" : "Not selected")
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 12)
            Image(libVM.books.isEmpty ? "LibraryEmptyState" : "SearchEmptyState")
                .resizable()
                .scaledToFit()
                .frame(width: isPad ? 270 : 220, height: isPad ? 260 : 220)
                .accessibilityHidden(true)
            Text(libVM.emptyStateTitle)
                .font(AppTypography.headline())
                .foregroundStyle(AppColors.textPrimary)
            Text(libVM.emptyStateMessage)
                .font(AppTypography.subheadline())
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
            if libVM.books.isEmpty {
                LibraryIconButton(
                    systemName: "plus",
                    accessibilityLabel: "Import EPUB",
                    fill: AppColors.actionPrimary,
                    foreground: .white,
                    size: 40,
                    action: libVM.importTapped
                )
                .padding(.top, 4)
            }
            Spacer(minLength: 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
}
