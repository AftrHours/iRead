import SwiftUI
import UIKit

/// Rendering metrics shared by the header, empty state, and collection.
@MainActor
struct LibraryLayout {
    let isPad: Bool
    let isSearching: Bool

    init(isPad: Bool = UIDevice.current.userInterfaceIdiom == .pad, isSearching: Bool = false) {
        self.isPad = isPad
        self.isSearching = isSearching
    }

    var sideMargin: CGFloat { isPad ? 34 : isSearching ? 20 : 16 }
    var gridColumnSpacing: CGFloat { isPad ? 18 : isSearching ? 20 : 12 }
    var gridRowSpacing: CGFloat { isPad ? 22 : isSearching ? 18 : 12 }
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
    var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: gridColumnSpacing, alignment: .top), count: isPad ? 4 : 2)
    }
}
