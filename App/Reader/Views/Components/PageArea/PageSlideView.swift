import SwiftUI

/// The page for the Slide and Fast Fade styles. Curl uses `PageTurnView`.
struct PageSlideView: UIViewRepresentable {
    let content: PageContent
    let actions: PageActions

    func makeUIView(context: Context) -> PageSlider {
        PageSlider()
    }

    func updateUIView(_ slider: PageSlider, context: Context) {
        slider.update(content, actions: actions)
    }
}

#Preview("Page Slide") {
    PagePreview { readerVM in
        if let content = readerVM.pageContent {
            PageSlideView(content: content, actions: .none)
        }
    }
}
