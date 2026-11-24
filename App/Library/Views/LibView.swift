import AVFAudio
import SwiftUI

/// Composes the Library screen. State transitions and user actions belong to LibVM.
struct LibView: View {
    @Bindable var libVM: LibVM
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceSelectionMotion
    @State private var inlineHeaderHeight: CGFloat = 76
    @State private var importSnapshot: [LibraryBookItemVM]?
    @State private var importPresentationID: UUID?
    @State private var importedIDs: [UUID] = []
    @State private var scrollToImportedBook: UUID?
    @FocusState private var isSearchFocused: Bool
    private var layout: LibraryLayout {
        LibraryLayout(viewMode: libVM.viewMode, isSearching: libVM.isSearchActive, isSelecting: libVM.isSelectionMode)
    }

    private var collectionItems: [LibraryBookItemVM] {
        if let importSnapshot { return importSnapshot }
        let items = libVM.bookItems
        guard !importedIDs.isEmpty else { return items }
        let waiting = Set(importedIDs)
        return items.filter { !waiting.contains($0.id) }
    }

    var body: some View {
        libraryContent
        .scrollEdgeEffectHidden(libVM.isSelectionMode, for: .bottom)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if libVM.isSelectionMode { selectionActions }
        }
        .allowsHitTesting(importPresentationID == nil)
        .accessibilityHidden(importPresentationID != nil)
        .overlay {
            if importPresentationID != nil {
                ZStack {
                    Color.black.opacity(0.48).ignoresSafeArea()
                    if let id = importedIDs.first {
                        LibraryImportFlight(image: libVM.covers[id], finish: { finishReveal(id) })
                            .id(id)
                            .transition(.identity)
                            .ignoresSafeArea()
                    }
                }
                .transition(.opacity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Adding books to your library")
            }
        }
        .task { await libVM.onAppear() }
        // Books shared from Apple Books wait in the App Group until the app comes back.
        .onChange(of: scenePhase) { _, scenePhase in
            if scenePhase == .active {
                Task { await libVM.appBecameActive() }
            } else if scenePhase == .background {
                libVM.stopDictation()
            }
        }
        .onDisappear {
            libVM.stopDictation()
            scrollToImportedBook = nil
            resetImportPresentation()
        }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)) { _ in
            libVM.stopDictation()
        }
        .alert("Voice search", isPresented: Binding(get: { libVM.voiceSearchError != nil }, set: { if !$0 { libVM.voiceSearchError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(libVM.voiceSearchError ?? "")
        }
        .onChange(of: isSearchFocused) { _, focused in libVM.searchFocusChanged(focused) }
        .onChange(of: libVM.isSearchActive) { _, active in isSearchFocused = active }
        .animation(layout.isPad ? nil : .easeInOut(duration: 0.2), value: libVM.isSearchActive)
        .background(AppColors.bgPrimary.ignoresSafeArea())
        .background {
            EPUBDocumentPicker(isPresented: $libVM.isImportPickerPresented, onPick: pickedFiles)
        }
        .alert(libVM.removalQuestion,
               isPresented: $libVM.isRemoveAlertPresented) {
            Button("Delete Everywhere", role: .destructive, action: libVM.removeConfirmed)
            Button("Cancel", role: .cancel, action: libVM.removeCancelled)
        }
        .fileExporter(isPresented: $libVM.isExportingBetaReport, document: libVM.betaReport,
                      contentType: .json, defaultFilename: "Refrn Beta Analytics", onCompletion: libVM.exportCompleted)
        .alert("Share beta analytics?", isPresented: $libVM.isBetaConsentPresented) {
            Button("Share", action: libVM.allowBetaSharing)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("""
            Send new usage, performance, and crash events to the Refrn team through iCloud using a random installation ID. \
            These reports exclude book titles, passages, and search terms.
            """)
        }
        .alert("Rename Book", isPresented: $libVM.isRenameAlertPresented) {
            TextField("Title", text: $libVM.renameDraft)
            Button("Save", action: libVM.renameConfirmed)
            Button("Cancel", role: .cancel, action: libVM.renameCancelled)
        }
        .alert("Couldn’t import EPUB", isPresented: Binding(
            get: { importPresentationID == nil && libVM.isImportAlertPresented },
            set: { if !$0 && importPresentationID == nil { libVM.dismissImportError() } }
        )) {
            Button("OK", role: .cancel, action: libVM.dismissImportError)
        } message: {
            Text(libVM.importErrorMessage)
        }
        .alert("Something went wrong", isPresented: $libVM.isBookActionAlertPresented) {
            Button("OK", role: .cancel, action: libVM.dismissBookActionError)
        } message: {
            Text(libVM.bookActionErrorMessage)
        }
    }

    private func pickedFiles(_ result: Result<[URL], any Error>) {
        guard case .success(let urls) = result, !urls.isEmpty else {
            libVM.importPickerCompleted(result)
            return
        }
        let presentationID = UUID()
        importSnapshot = libVM.bookItems
        withAnimation(.easeOut(duration: 0.18)) { importPresentationID = presentationID }
        Task {
            await libVM.importFiles(result) { added in
                guard importPresentationID == presentationID else { return }
                let visible = Set(libVM.visibleBooks.map(\.id))
                importedIDs = added.filter(visible.contains)
                if importedIDs.isEmpty { resetImportPresentation() }
            }
        }
    }

    private func finishReveal(_ id: UUID) {
        guard importedIDs.first == id else { return }
        if let book = libVM.allBooks.first(where: { $0.id == id }) {
            AccessibilityNotification.Announcement("Added \(book.title) to your library").post()
        }
        importSnapshot = nil
        scrollToImportedBook = id
        if importedIDs.count == 1 {
            withAnimation(.easeOut(duration: 0.22)) { resetImportPresentation() }
        } else {
            importedIDs.removeFirst()
        }
    }

    private func resetImportPresentation() {
        importSnapshot = nil
        importedIDs.removeAll()
        importPresentationID = nil
    }

    @ViewBuilder
    private var libraryContent: some View {
        if layout.isPad {
            VStack(alignment: .leading, spacing: 0) {
                if collectionItems.isEmpty {
                    if !libVM.isSelectionMode && !libVM.isSearchActive {
                        LibraryTitleView()
                            .padding(.horizontal, layout.sideMargin)
                            .padding(.top, 10)
                            .padding(.bottom, 12)
                    }
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
                if libVM.isSearchActive, let resultsTitle = libVM.searchResultsTitle {
                    Text(resultsTitle)
                        .accessibilityAddTraits(.isHeader)
                        .font(AppTypography.title2(.bold))
                        .foregroundStyle(AppColors.textPrimary)
                        .padding(.horizontal, layout.sideMargin)
                        .padding(.bottom, 16)
                }

                if collectionItems.isEmpty {
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

    private var selectionActions: some View {
        HStack {
            Button(libVM.areVisibleBooksSelected ? "Deselect All" : "Select All", action: libVM.toggleVisibleSelection)
                .font(AppTypography.body(.medium))
                .padding(.horizontal, 20)
                .frame(minHeight: 48)
                .glassEffect(.regular.interactive(), in: .capsule)
                .disabled(libVM.isCollectionEmpty)
            Spacer()
            Button(action: libVM.removeSelectionTapped) {
                Image(systemName: "trash")
                    .font(AppTypography.title2())
                    .libraryIconFrame()
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .libraryControlLabel("Delete selected books", symbol: "trash")
            .accessibilityValue(libVM.selectionTitle)
            .disabled(libVM.selectedBookIDs.isEmpty || libVM.isRemovingBooks)
        }
        .buttonStyle(.plain)
        .foregroundStyle(AppColors.textPrimary)
        .padding(.horizontal, layout.isPad ? layout.collectionSideMargin : 16)
        .padding(.bottom, 2)
    }

    private var bookCollection: some View {
        LibraryBookCollection(
            scrollToImportedBook: $scrollToImportedBook,
            items: collectionItems,
            layout: layout,
            onBookTapped: libVM.bookTapped,
            onFinished: libVM.finishedToggled,
            onRename: libVM.renameTapped,
            onRemove: libVM.removeTapped,
            showsLibraryTitle: layout.isPad && !libVM.isSelectionMode && !libVM.isSearchActive,
            resultsTitle: layout.isPad && libVM.isSearchActive ? libVM.searchResultsTitle : nil,
            onScrolled: { offset in
                if !layout.isPad { libVM.libraryScrolled(to: offset, headerHeight: inlineHeaderHeight) }
            },
            header: {
                if !layout.isPad && !libVM.isSearchActive && !libVM.isSelectionMode {
                    VStack(alignment: .leading, spacing: 0) {
                        if dynamicTypeSize.isAccessibilitySize {
                            LibraryTitleView()
                        }
                        LibrarySearchBar(libVM: libVM, focus: $isSearchFocused)
                            .padding(.top, 16)
                            .padding(.bottom, 20)
                    }
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { inlineHeaderHeight = $0 }
                }
            }
        )
        .animation(libVM.isSelectionMode && !reduceSelectionMotion ? .smooth(duration: 0.5) : nil,
                   value: libVM.selectedBookIDs)
    }
}

private struct LibraryImportFlight: View {
    let image: UIImage?
    let finish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date.now

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let width = min(size.width * 0.37, size.height * 0.4, 220)
            let height = width / BookCoverView.aspectRatio
            // Clear the screen with the entire cover, including its glow.
            let travel = (size.height + height) / 2 + 30
            let flight = KeyframeTimeline(initialValue: travel) {
                CubicKeyframe(-12, duration: 0.68, startVelocity: 0, endVelocity: 0)
                CubicKeyframe(3, duration: 0.20, endVelocity: 0)
                CubicKeyframe(0, duration: 0.16, endVelocity: 0)
                LinearKeyframe(0, duration: 0.24)
                CubicKeyframe(-travel, duration: 0.66, startVelocity: 0, endVelocity: 0)
            }
            let duration = reduceMotion ? 0.8 : flight.duration
            TimelineView(.animation) { tick in
                let time = min(duration, max(0, tick.date.timeIntervalSince(start)))
                let offset = reduceMotion ? 0 : flight.value(time: time)
                let opacity = reduceMotion ? min(1, time / 0.2, (duration - time) / 0.2) : 1
                BookCoverView(image: image)
                    .frame(width: width, height: height)
                    .shadow(color: .white.opacity(0.5), radius: 10)
                    .position(x: size.width / 2, y: size.height / 2 + offset)
                    .opacity(opacity)
                    .onChange(of: time >= duration, initial: true) { _, completed in
                        if completed { finish() }
                    }
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

#Preview("Library — Largest Text") {
    LibView(libVM: PreviewFixtures.libraryVM())
        .environment(\.dynamicTypeSize, .accessibility4)
}

#Preview("Select Books — Grid") {
    @Previewable @State var model = PreviewFixtures.libraryVM()
    LibView(libVM: model)
        .onAppear { model.selectionModeTapped() }
        .preferredColorScheme(.dark)
}

#Preview("Select Books — List") {
    @Previewable @State var model = PreviewFixtures.libraryVM()
    LibView(libVM: model)
        .onAppear {
            model.viewModeSelected(.list)
            model.selectionModeTapped()
            for sample in BookRecord.samples.prefix(2) { model.selectionTapped(sample.book) }
        }
        .preferredColorScheme(.dark)
}
