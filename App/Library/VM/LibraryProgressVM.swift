import Foundation

/// Validated progress and accessibility copy, independent of the view's geometry.
struct LibraryProgressVM {
    let fraction: Double

    init(progress: Double) {
        fraction = min(max(progress, 0), 1)
    }

    var accessibilityLabel: String { "\(Int((fraction * 100).rounded()))% read" }
}
