import SwiftUI

/// The page for the Slide and Fast Fade styles. Curl uses `PageTurnView`.
struct PageSlideView: UIViewRepresentable {
    let pages: [Page]
    let shownPage: Page
    let settings: ReadingSettings
    let horizontalMargin: CGFloat
    let marks: [Int: [Mark]]
    let chrome: (Page) -> PageChrome
    let frames: PageFrames
    let onPageChanged: (Page) -> Void
    let onCenterTapped: () -> Void
    let onMarkTapped: (Mark, CGRect) -> Void

    func makeUIView(context: Context) -> PageSlider {
        PageSlider()
    }

    func updateUIView(_ slider: PageSlider, context: Context) {
        slider.onPageChanged = onPageChanged
        slider.onCenterTapped = onCenterTapped
        slider.onMarkTapped = onMarkTapped
        slider.update(.init(pages: pages, shownPage: shownPage, settings: settings,
                            horizontalMargin: horizontalMargin, marks: marks, chrome: chrome, frames: frames))
    }
}
