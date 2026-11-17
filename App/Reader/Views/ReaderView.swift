import SwiftUI
import UIKit


struct ReaderView: View {
    @Bindable private var readerVM: ReaderVM
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private static let returnControlsBottom: CGFloat = PageLayoutKnobs.barHeight + 9 - 5

    private let readerSettingsVM: ReaderSettingsVM
    private let referenceVM: ReferenceVM
    private let ratingVM: RatingVM

    private var pageTextColor: Color {
        Color(PageTextStyle.textColor(for: readerVM.theme))
    }

    private var pageColorScheme: ColorScheme {
        readerVM.isDarkPage ? .dark : .light
    }

    init(readerVM: ReaderVM) {
        self.readerVM = readerVM
        readerSettingsVM = readerVM.readerSettingsVM
        referenceVM = readerVM.referenceVM
        ratingVM = readerVM.ratingVM
    }

    var body: some View {
        ZStack {
            PageArea(readerVM: readerVM, referenceVM: referenceVM, ratingVM: ratingVM)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                TopBar(
                    foreground: pageTextColor,
                    colorScheme: pageColorScheme,
                    isFocusMode: readerVM.isFocusMode,
                    onBack: readerVM.backTapped,
                    onUnderlineDebug: underlineDebugAction
                )
                Spacer()
                BottomBar(
                    foreground: pageTextColor,
                    colorScheme: pageColorScheme,
                    isFocusMode: readerVM.isFocusMode
                ) {
                    ToolbarList(readerVM: readerVM)
                }
            }
            .padding(.horizontal, PageLayoutKnobs.sideMargin)
        }

        .onGeometryChange(for: ScreenGeometry.self) {
            ScreenGeometry(safeSize: $0.size, safeAreaTop: $0.safeAreaInsets.top, safeAreaBottom: $0.safeAreaInsets.bottom)
        } action: {
            readerVM.screenChanged($0)
        }
        .task { await readerVM.onAppear() }
        .overlay {
            ReferredButton(
                prompt: referenceVM.returnPrompt,
                onDismiss: referenceVM.returnDismissed,
                onReturn: referenceVM.returnToReadingTapped
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, Self.returnControlsBottom)
        }
        .background(Color(PageTextStyle.backgroundColor(for: readerVM.theme)))
        .preferredColorScheme(readerVM.forcedDarkMode.map { $0 ? .dark : .light })
        .onChange(of: colorScheme, initial: true) { _, colorScheme in
            readerVM.systemAppearanceChanged(isDark: colorScheme == .dark)
        }
        .onChange(of: horizontalSizeClass, initial: true) { _, horizontalSizeClass in
            readerVM.widthClassChanged(isRegular: horizontalSizeClass == .regular)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIScreen.brightnessDidChangeNotification)) { _ in
            readerSettingsVM.screenBrightnessChanged()
        }
        .animation(.easeInOut, value: referenceVM.returnPrompt)
        .animation(.easeInOut(duration: 0.2), value: readerVM.isFocusMode)
        .onChange(of: scenePhase) { _, scenePhase in
            if scenePhase == .background {
                readerVM.appBackgrounded()
            } else if scenePhase == .active {
                readerVM.appForegrounded()
            }
        }
        .overlay {
            if readerVM.isSettingsPanelShown {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture(perform: readerVM.sheetDismissed)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel("Close Reading Theme & Settings")
                    .transition(.opacity)
            }
        }
        .overlay {
            if readerVM.isSettingsPanelShown {
                ThemeSettingsPanel(readerSettingsVM: readerSettingsVM, onClose: readerVM.sheetDismissed)
                    .transition(.move(edge: .bottom))
            }
        }
        .animation(.smooth(duration: 0.35), value: readerVM.isSettingsPanelShown)
        .sheet(item: $readerVM.presentedSheet) { sheet in
            switch sheet {
            case .contents:
                ContentsSheet(
                    chapterTitles: readerVM.chapterTitles,
                    startPageLabel: readerVM.startPageLabel(ofChapter:),
                    onChapterTapped: readerVM.chapterTapped
                )
            case .search(let searchVM):
                SearchView(searchVM: searchVM)
            case .themeSettings:
                ThemeSettingsView(readerSettingsVM: readerSettingsVM, onClose: readerVM.sheetDismissed)
            }
        }
        #if DEBUG
        .sheet(isPresented: $readerVM.isUnderlineDebugSheetPresented) {
            UnderlineDebugView(underlineDebugVM: readerVM.makeUnderlineDebugVM())
        }
        #endif
    }

    private var underlineDebugAction: (() -> Void)? {
        #if DEBUG
        readerVM.underlineDebugTapped
        #else
        nil
        #endif
    }

}

#if DEBUG
@MainActor
private func previewReader(_ title: String = "Little Women") -> ReaderView {
    let book = BookRecord.samples.first { $0.book.title == title }?.book ?? BookRecord.samples[0].book
    return ReaderView(readerVM: AppContainer.forPreviews().makeReaderVM(book: book))
}

#Preview("Reader") {
    previewReader()
}
#endif
