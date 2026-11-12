import Foundation
import UIKit

/// Values prepared for rendering; views only forward user events to LibVM.
extension LibVM {
    var menuViewMode: ViewMode {
        get { viewMode }
        set { viewModeSelected(newValue) }
    }

    var menuSortOption: LibrarySortOption {
        get { sortOption }
        set { sortChanged(newValue) }
    }

    var bookItems: [LibraryBookItemVM] {
        visibleBooks.map {
            LibraryBookItemVM(book: $0, cover: covers[$0.id], showsSelection: isSelectionMode,
                              isSelected: selectedBookIDs.contains($0.id))
        }
    }

    var isCollectionEmpty: Bool { visibleBooks.isEmpty }
    var searchResultsTitle: String? {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let count = visibleBooks.count
        guard count > 0 else { return nil }
        return count == 1 ? "1 Result" : "\(count) Results"
    }

    var showsImportInEmptyState: Bool { allBooks.isEmpty }
    var emptyStateImage: UIImage? {
        allBooks.isEmpty ? Self.libraryEmptyIllustration : Self.searchEmptyIllustration
    }
    var selectionTitle: String { "\(selectedBookIDs.count) Selected" }
    var voiceSearchSymbol: String { isVoiceSearchActive ? "waveform" : "mic" }
    var voiceSearchAccessibilityLabel: String { isVoiceSearchActive ? "Stop voice search" : "Search by voice" }
    var isAccountSignedIn: Bool { cloudAccount == .signedIn }
    var importErrorMessage: String { importError ?? "Please try another EPUB file." }
    var voiceSearchErrorMessage: String { voiceSearchError ?? "Voice search is unavailable." }
    var bookActionErrorMessage: String { bookActionError ?? "" }

    var menuSortOptions: [LibrarySortOption] { LibrarySortOption.menuOptions }

    private static let libraryEmptyIllustration = loadIllustration(named: "LibraryEmptyState")
    private static let searchEmptyIllustration = loadIllustration(named: "SearchEmptyState")

    private static func loadIllustration(named name: String) -> UIImage? {
        let bundle = Bundle(for: LibVM.self)
        guard let url = bundle.url(forResource: name, withExtension: "png") else { return nil }
        return UIImage(contentsOfFile: url.path)
    }
}
