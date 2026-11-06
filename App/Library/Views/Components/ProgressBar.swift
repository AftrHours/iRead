import SwiftUI

/// A compact reading-progress indicator used in the grid and row layouts.
struct ProgressBar: View {
    let progress: Double

    private var clampedProgress: Double { min(max(progress, 0), 1) }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle().fill(LibraryPalette.progressTrack)
                Rectangle()
                    .fill(LibraryPalette.progressFill)
                    .frame(width: geometry.size.width * clampedProgress)
            }
        }
        .frame(height: 6)
        .accessibilityElement()
        .accessibilityLabel("\(Int((clampedProgress * 100).rounded()))% read")
    }
}
