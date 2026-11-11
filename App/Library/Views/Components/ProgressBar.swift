import SwiftUI

/// A compact reading-progress indicator used in the grid and row layouts.
struct ProgressBar: View {
    let progress: Double

    private var clampedProgress: Double { min(max(progress, 0), 1) }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle().fill(AppColors.readerReferencePanel)
                Rectangle()
                    .fill(AppColors.actionPrimary)
                    .frame(width: geometry.size.width * clampedProgress)
            }
        }
        .frame(height: 4)
        .accessibilityElement()
        .accessibilityLabel("\(Int((clampedProgress * 100).rounded()))% read")
    }
}

#Preview("Reading Progress") {
    VStack(alignment: .leading, spacing: 16) {
        ProgressBar(progress: 0.32)
        ProgressBar(progress: 0.76)
        ProgressBar(progress: 1)
    }
    .frame(width: 240)
    .padding()
}
