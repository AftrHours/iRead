import SwiftUI
import UIKit

struct ReaderView: View {
    @Bindable private var readerVM: ReaderVM
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private let readerSettingsVM: ReaderSettingsVM
    private let referenceVM: ReferenceVM
    private var theme: ReadingTheme { readerSettingsVM.layoutSettings.theme }

    private var pageTextColor: Color { Color(PageTextStyle.textColor(for: theme)) }

    /// The reading mode's choice, or the device's for Match Device.
    private var isDarkMode: Bool {
        readerSettingsVM.isDarkMode ?? (colorScheme == .dark)
    }

    private var pageColorScheme: ColorScheme {
        PageTextStyle.isDarkPage(theme, isDarkMode: isDarkMode) ? .dark : .light
    }

    /// On a full-width iPad the settings are a panel attached to the bottom edge, not iOS's floating form sheet.
    private var isSettingsPanelShown: Bool {
        guard horizontalSizeClass == .regular, case .themeSettings = readerVM.sheet else { return false }
        return true
    }

    /// The sheet to present: everything but the iPad's settings panel.
    private var presentedSheet: ReaderVM.Sheet? {
        isSettingsPanelShown ? nil : readerVM.sheet
    }

    /// nil leaves the device's light or dark style alone.
    private var readingColorScheme: ColorScheme? {
        readerSettingsVM.isDarkMode.map { $0 ? .dark : .light }
    }

    init(readerVM: ReaderVM) {
        self.readerVM = readerVM
        readerSettingsVM = readerVM.readerSettingsVM
        referenceVM = readerVM.referenceVM
    }

    var body: some View {
        VStack(spacing: 0) {
            TopBar(
                title: readerVM.title,
                chapterTitle: readerVM.chapterTitle,
                foreground: pageTextColor,
                colorScheme: pageColorScheme,
                isFocusMode: readerVM.isFocusMode,
                onBack: readerVM.backTapped,
                onUnderlineDebug: underlineDebugAction
            )
            .padding(.horizontal)
            .padding(.top)
            
            // 9.5% of the width each side, like Apple Books: about 78pt on an iPad in portrait, 38pt on an iPhone.
            PageArea(readerVM: readerVM, textMarginRatio: 0.09)
                .padding(.top)
                .padding(.bottom)
            
            BottomBar(
                pageLabel: readerVM.pageLabel,
                foreground: pageTextColor,
                colorScheme: pageColorScheme,
                isFocusMode: readerVM.isFocusMode,
                canReturn: referenceVM.canReturn,
                toastText: referenceVM.toastText,
                onReturnDismissed: referenceVM.returnDismissed,
                onReturnTapped: referenceVM.returnToReadingTapped
            ) {
                ToolbarList(readerVM: readerVM)
            }
            .padding(.leading,36)
            .padding(.trailing)
        }
        .background(Color(PageTextStyle.backgroundColor(for: theme)))
        // The reading mode applies to the page, its controls and the sheets, and ends when the reader closes.
        .preferredColorScheme(readingColorScheme)
        .onReceive(NotificationCenter.default.publisher(for: UIScreen.brightnessDidChangeNotification)) { _ in
            readerSettingsVM.screenBrightnessChanged()
        }
        .animation(.easeInOut, value: referenceVM.toastText)
        .animation(.easeInOut(duration: 0.2), value: readerVM.isFocusMode)
        .onChange(of: scenePhase) { _, scenePhase in
            if scenePhase == .background {
                readerVM.appBackgrounded()
            } else if scenePhase == .active {
                readerVM.appForegrounded()
            }
        }
        .overlay {
            if isSettingsPanelShown {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture(perform: readerVM.sheetDismissed)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel("Close Reading Theme & Settings")
                    .transition(.opacity)
            }
        }
        .overlay {
            if isSettingsPanelShown {
                ThemeSettingsPanel(readerSettingsVM: readerSettingsVM, onClose: readerVM.sheetDismissed)
                    .transition(.move(edge: .bottom))
            }
        }
        .animation(.smooth(duration: 0.35), value: isSettingsPanelShown)
        .sheet(item: Binding(get: { presentedSheet }, set: { _ in readerVM.sheetDismissed() })) { sheet in
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
