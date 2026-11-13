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
    var hasSearchQuery: Bool { !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var showsSearchEmptyState: Bool { hasSearchQuery && isCollectionEmpty }
    var searchResultsTitle: String? {
        guard hasSearchQuery else { return nil }
        let count = visibleBooks.count
        guard count > 0 else { return nil }
        return count == 1 ? "1 Result" : "\(count) Results"
    }

    var isLibraryEmpty: Bool { allBooks.isEmpty }
    var emptyStateImage: UIImage? {
        showsSearchEmptyState ? Self.searchEmptyIllustration : Self.libraryEmptyIllustration
    }
    var selectionTitle: String { "\(selectedBookIDs.count) Selected" }
    var voiceSearchSymbol: String { isVoiceSearchActive ? "waveform" : "mic.fill" }
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
