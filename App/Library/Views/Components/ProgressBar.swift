import SwiftUI

/// A compact reading-progress indicator used in the grid and row layouts.
struct ProgressBar: View {
    enum Style {
        case card
        case list

        var horizontalInset: CGFloat { self == .card ? 12 : 0 }
        var height: CGFloat { self == .card ? 8 : 4 }
    }

    let progress: LibraryProgressVM
    var style: Style = .card

    var body: some View {
        GeometryReader { geometry in
            let barWidth = max(0, geometry.size.width - style.horizontalInset * 2)
            ZStack(alignment: .leading) {
                Capsule().fill(AppColors.cardProgressTrack)
                Capsule()
                    .fill(AppColors.actionPrimary)
                    .frame(width: barWidth * progress.fraction)
            }
            .frame(width: barWidth, height: style.height, alignment: .leading)
            .clipShape(Capsule())
            .frame(width: geometry.size.width, height: style.height, alignment: .center)
        }
        .frame(height: style.height)
        .accessibilityElement()
        .accessibilityLabel(progress.accessibilityLabel)
    }
}

#Preview("List Reading Progress") {
    ProgressBar(progress: LibraryProgressVM(progress: 0.4), style: .list)
        .frame(width: 60)
        .padding()
}

#Preview("Reading Progress") {
    VStack(alignment: .leading, spacing: 16) {
        ProgressBar(progress: LibraryProgressVM(progress: 0.32))
        ProgressBar(progress: LibraryProgressVM(progress: 0.76))
        ProgressBar(progress: LibraryProgressVM(progress: 1))
    }
    .frame(width: 240)
    .padding()
}
