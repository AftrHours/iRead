import AVFAudio
import SwiftUI

/// Composes the Library screen. State transitions and user actions belong to LibVM.
struct LibView: View {
    @Bindable var libVM: LibVM
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var inlineHeaderHeight: CGFloat = 76
    @State private var importSnapshot: [LibraryBookItemVM]?
    @State private var importPresentationID: UUID?
    @State private var importedIDs: [UUID] = []
    @State private var destination: UUID?
    @FocusState private var isSearchFocused: Bool
    private var layout: LibraryLayout {
        LibraryLayout(viewMode: libVM.viewMode, isSearching: libVM.isSearchActive, isSelecting: libVM.isSelectionMode)
    }

    private var collectionItems: [LibraryBookItemVM] {
        if let importSnapshot { return importSnapshot }
        let items = libVM.bookItems
        guard !importedIDs.isEmpty else { return items }
        let waiting = Set(importedIDs.dropFirst(destination == nil ? 0 : 1))
        return items.filter { !waiting.contains($0.id) }
    }

    var body: some View {
        libraryContent
        .scrollEdgeEffectHidden(libVM.isSelectionMode, for: .bottom)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if libVM.isSelectionMode { selectionActions }
        }
        .environment(\.libraryImportDestination, destination)
        .allowsHitTesting(importPresentationID == nil)
        .accessibilityHidden(importPresentationID != nil)
        .overlayPreferenceValue(LibraryImportCoverAnchor.self) { anchor in
            if importPresentationID != nil {
                ZStack {
                    Color.black.opacity(0.48).ignoresSafeArea()
                    if let id = importedIDs.first {
                        GeometryReader { geometry in
                            LibraryImportFlight(image: libVM.covers[id], viewport: geometry.size,
                                                slot: anchor.map { geometry[$0] },
                                                requestSlot: {
                                                    importSnapshot = nil
                                                    destination = id
                                                },
                                                finish: { finishReveal(id) })
                                .id(id)
                        }
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
            These reports exclude book titles, passages, and search terms. You can stop sharing from the Library menu.
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
        if importedIDs.count == 1 {
            withAnimation(.easeOut(duration: 0.22)) { resetImportPresentation() }
        } else {
            destination = nil
            importedIDs.removeFirst()
        }
    }

    private func resetImportPresentation() {
        importSnapshot = nil
        destination = nil
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
            }
        ) {
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
    }
}

/// Resolves the destination from the real cover after the sorted collection has laid it out.
private struct LibraryImportFlight: View {
    let image: UIImage?
    let viewport: CGSize
    let slot: CGRect?
    let requestSlot: () -> Void
    let finish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var opacity = 0.0
    @State private var landing = false

    private var centeredCover: CGRect {
        let width = min(viewport.width * 0.37, viewport.height * 0.4, 220)
        let height = width / BookCoverView.aspectRatio
        return CGRect(x: (viewport.width - width) / 2, y: (viewport.height - height) / 2,
                      width: width, height: height)
    }

    private var hasVisibleSlot: Bool {
        guard let slot, !slot.isEmpty else { return false }
        return CGRect(origin: .zero, size: viewport).contains(CGPoint(x: slot.midX, y: slot.midY))
    }

    var body: some View {
        let frame = landing && !reduceMotion ? slot ?? centeredCover : centeredCover
        BookCoverView(image: image)
            .frame(width: frame.width, height: frame.height)
            .shadow(color: .white.opacity(landing ? 0 : 0.45), radius: 5)
            .position(x: frame.midX, y: frame.midY)
            .opacity(opacity)
            .task {
                withAnimation(.easeOut(duration: 0.22)) { opacity = 1 }
                do {
                    try await Task.sleep(for: .milliseconds(650))
                    requestSlot()
                    // If layout cannot supply a visible slot, always return control to the library.
                    try await Task.sleep(for: .seconds(2))
                    if !landing { finish() }
                } catch { return }
            }
            .task(id: hasVisibleSlot) {
                guard !landing, hasVisibleSlot else { return }
                withAnimation(.easeInOut(duration: reduceMotion ? 0.22 : 0.65), completionCriteria: .logicallyComplete) {
                    landing = true
                    if reduceMotion { opacity = 0 }
                } completion: {
                    finish()
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
