import SwiftUI
import UIKit

/// Rendering metrics shared by the header, empty state, and collection.
@MainActor
struct LibraryLayout {
    static let maximumIconSize = DynamicTypeSize.accessibility1

    let isPad: Bool
    let isSearching: Bool
    let isSelecting: Bool
    let viewMode: LibVM.ViewMode

    init(isPad: Bool = UIDevice.current.userInterfaceIdiom == .pad, viewMode: LibVM.ViewMode, isSearching: Bool = false,
         isSelecting: Bool = false) {
        self.isSelecting = isSelecting
        self.isSearching = isSearching
        self.viewMode = viewMode
        self.isPad = isPad
    }

    // Searching filters the iPhone grid while keeping the same book cards.
    var isBrowsingOnPhone: Bool {
        !isPad && !isSelecting && (viewMode == .grid || !isSearching)
    }

    var isSelectingOnPhone: Bool { !isPad && isSelecting }
    var usesPhoneListSpacing: Bool { isBrowsingOnPhone || isSelectingOnPhone }

    var sideMargin: CGFloat { isPad ? 30 : 16 }
    var collectionSideMargin: CGFloat {
        if isPad { return 30 }
        guard viewMode == .grid else { return 16 }
        return isSelecting && !isSearching ? 25 : 20
    }
    var gridColumnSpacing: CGFloat {
        if isPad { return 30 }
        return isSelecting && !isSearching ? 26 : 18
    }
    let rowSpacing: CGFloat = 16
    var emptySearchImageSize: CGSize { CGSize(width: isPad ? 270 : 210, height: isPad ? 210 : 164) }
    var emptySearchImageSpacing: CGFloat { isPad ? 32 : 26 }
    var emptyLibraryImageSize: CGSize {
        let side: CGFloat = isPad ? 270 : 253
        return CGSize(width: side, height: side)
    }
    // Center the bookshelf itself, allowing for the cobweb extending to its right.
    var emptyLibraryImageOffset: CGFloat { isPad ? 16 : 14 }
    var emptyLibraryImageSpacing: CGFloat { isPad ? 40 : 35 }
    var emptyLibraryTextSpacing: CGFloat { isPad ? 8 : 8.5 }
    var emptyLibraryButtonSpacing: CGFloat { isPad ? 24 : 25 }
    var emptyLibraryBottomInset: CGFloat { isPad ? 0 : 68.5 }
    func gridColumns(for size: DynamicTypeSize) -> [GridItem] {
        if size.isAccessibilitySize {
            return [GridItem(.adaptive(minimum: 260), spacing: gridColumnSpacing, alignment: .top)]
        }
        return Array(repeating: GridItem(.flexible(), spacing: gridColumnSpacing, alignment: .top), count: isPad ? 4 : 2)
    }
}

extension EnvironmentValues {
    @Entry var isBrowsingLibraryOnPhone = false
    @Entry var isSelectingLibraryOnPhone = false
}
