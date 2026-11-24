import SwiftUI

/// A compact reading-progress indicator used in the grid and row layouts.
struct ProgressBar: View {
    enum Style {
        case card
        case list
    }

    @Environment(\.isBrowsingLibraryOnPhone) private var isPhoneBrowse
    @Environment(\.isSelectingLibraryOnPhone) private var isPhoneSelection
    let progress: LibraryProgressVM
    var style: Style = .card

    private var inset: CGFloat { style == .card ? (isPhoneBrowse ? 12 : 11) : 0 }
    private var height: CGFloat {
        switch style {
        case .card: isPhoneBrowse || isPhoneSelection ? 10 : 8
        case .list: isPhoneBrowse || isPhoneSelection ? 5 : 4
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let barWidth = max(0, geometry.size.width - inset * 2)
            ZStack(alignment: .leading) {
                Capsule().fill(AppColors.progressBarBg)
                Capsule()
                    .fill(AppColors.progressBarLine)
                    .frame(width: barWidth * progress.fraction)
            }
            .frame(width: barWidth, height: height, alignment: .leading)
            .clipShape(Capsule())
            .frame(width: geometry.size.width, height: height, alignment: .center)
        }
        .frame(height: height)
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
