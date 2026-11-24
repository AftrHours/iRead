import SwiftUI

/// The progress bar and page label, drawn once over the pages, so they stay still while a page slides or curls.
/// Placed where each page leaves room for them (`PageLayout.footer`).
struct PageFooter: View {
    let chrome: PageChrome
    let footer: CGRect
    let textColor: UIColor

    private typealias Knobs = PageLayoutKnobs

    private var barWidth: CGFloat {
        min(Knobs.progressBarWidth, footer.width - 2 * footer.height)
    }

    var body: some View {
        VStack(spacing: Knobs.progressBarGap) {
            if let progress = chrome.progress {
                Capsule()
                    .fill(AppColors.progressBarBg)
                    .overlay(alignment: .leading) {
                        Rectangle().fill(AppColors.progressBarLine).frame(width: barWidth * progress)
                    }
                    .overlay(alignment: .leading) {
                        if let returnMark = chrome.returnMark {
                            Rectangle()
                                .fill(Color(AppColors.readerReturnMark))
                                .frame(width: Knobs.returnMarkWidth)
                                .offset(x: barWidth * returnMark - Knobs.returnMarkWidth / 2)
                        }
                    }
                    .clipShape(.capsule)
                    .frame(width: barWidth, height: Knobs.progressBarHeight)
                    .accessibilityHidden(true)
            }
            // Crossfades, as "Page 12 of 300" turns into "Returned to page 12" and back.
            Text(chrome.pageLabel)
                .font(.caption)
                .foregroundStyle(Color(textColor))
                .lineLimit(1)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.25), value: chrome.pageLabel)
                .frame(width: max(0, footer.width - 2 * (footer.height + 4)))
        }
        .position(x: footer.midX, y: footer.midY)
        .allowsHitTesting(false)
    }
}
