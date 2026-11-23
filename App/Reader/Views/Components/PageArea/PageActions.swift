import Foundation

/// What a page tells the reader: the page turned, the middle tapped, an underline tapped. The pagers only forward these.
struct PageActions {
    var onPageChanged: (Page) -> Void
    var onCenterTapped: () -> Void
    var onTurnBegan: () -> Void = {}
    var claimReadingFocus: (UUID) -> Bool = { _ in false }
    var onMarkTapped: (Mark, CGRect) -> Void

    static var none: PageActions {
        PageActions(onPageChanged: { _ in }, onCenterTapped: {}, onMarkTapped: { _, _ in })
    }
}
