import SwiftUI
import UIKit

/// Rendering metrics shared by the header, empty state, and collection.
@MainActor
struct LibraryLayout {
    let isPad: Bool

    init(isPad: Bool = UIDevice.current.userInterfaceIdiom == .pad) {
        self.isPad = isPad
    }

    var sideMargin: CGFloat { isPad ? 34 : 16 }
    var gridColumnSpacing: CGFloat { isPad ? 18 : 12 }
    var gridRowSpacing: CGFloat { isPad ? 22 : 12 }
    var emptyImageSize: CGSize { CGSize(width: isPad ? 270 : 220, height: isPad ? 260 : 220) }
    var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: gridColumnSpacing, alignment: .top), count: isPad ? 4 : 2)
    }
}
