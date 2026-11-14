import SwiftUI

/// The iPad's settings: attached to the bottom edge like the design, where iOS would float a form sheet in the middle.
struct ThemeSettingsPanel: View {
    let readerSettingsVM: ReaderSettingsVM
    let onClose: () -> Void
    @State private var dragOffset: CGFloat = 0

    /// The design's panel on an 11-inch iPad.
    private static let size = CGSize(width: 752, height: 932)
    /// Pulling the handle down this far closes the panel.
    private static let closeDistance: CGFloat = 120

    var body: some View {
        GeometryReader { proxy in
            ThemeSettingsView(readerSettingsVM: readerSettingsVM, onClose: onClose)
                .safeAreaPadding(.top, 12)
                .frame(width: min(Self.size.width, proxy.size.width - 40),
                       height: min(Self.size.height, proxy.size.height * 0.8))
                .background(AppColors.settingsSheetBackground)
                .overlay(alignment: .top) { handle }
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 34, topTrailingRadius: 34))
                .shadow(color: .black.opacity(0.25), radius: 24)
                .offset(y: dragOffset)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    /// The drag indicator, with a strip under it to pull the panel down by.
    private var handle: some View {
        Capsule()
            .fill(AppColors.settingsGrabber)
            .frame(width: 60, height: 5)
            .padding(.top, 6)
            // Narrow, so it never covers the close button.
            .frame(width: 120, height: 24, alignment: .top)
            .contentShape(.rect)
            .gesture(
                DragGesture()
                    .onChanged { dragOffset = max(0, $0.translation.height) }
                    .onEnded { value in
                        if value.translation.height > Self.closeDistance {
                            onClose()
                        }
                        dragOffset = 0
                    }
            )
            .accessibilityHidden(true)
    }
}

#Preview("Theme & Settings – iPad panel", traits: .fixedLayout(width: 834, height: 1194)) {
    @Previewable @State var readerSettingsVM = PreviewFixtures.readerSettingsVM()
    ZStack {
        Color.gray.opacity(0.3)
        ThemeSettingsPanel(readerSettingsVM: readerSettingsVM, onClose: {})
    }
}
