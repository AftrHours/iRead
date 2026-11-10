import SwiftUI

struct ReaderView: View {
    @Bindable private var readerVM: ReaderVM
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme

    private let readerSettingsVM: ReaderSettingsVM
    private let referenceVM: ReferenceVM
    private var theme: ReadingTheme { readerSettingsVM.layoutSettings.theme }

    private var pageTextColor: Color { Color(PageTextStyle.textColor(for: theme)) }

    private var pageColorScheme: ColorScheme {
        switch theme {
        case .original: colorScheme
        case .quiet: .dark
        case .paper, .bold, .calm, .focus: .light
        }
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
        .animation(.easeInOut, value: referenceVM.toastText)
        .animation(.easeInOut(duration: 0.2), value: readerVM.isFocusMode)
        .onChange(of: scenePhase) { _, scenePhase in
            if scenePhase == .background {
                readerVM.appBackgrounded()
            } else if scenePhase == .active {
                readerVM.appForegrounded()
            }
        }
        .sheet(item: Binding(get: { readerVM.sheet }, set: { _ in readerVM.sheetDismissed() })) { sheet in
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
                ThemeSettingsView(readerSettingsVM: readerSettingsVM)
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
