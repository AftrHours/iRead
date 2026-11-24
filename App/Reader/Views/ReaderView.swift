import SwiftUI
import UIKit

struct ReaderView: View {
    @Bindable private var readerVM: ReaderVM
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let readerSettingsVM: ReaderSettingsVM
    private let referenceVM: ReferenceVM
    private let ratingVM: RatingVM
    private let characterVM: CharacterVM

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
        characterVM = readerVM.characterVM
    }

    var body: some View {
        let barHeight = PageLayoutKnobs.controlSize(PageLayoutKnobs.barHeight, at: dynamicTypeSize)
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
                    isFocusMode: readerVM.isFocusMode,
                    canReturn: referenceVM.returnPrompt == .canReturn,
                    onReturn: referenceVM.returnToReadingTapped
                ) {
                    ToolbarList(readerVM: readerVM)
                }
            }
            .padding(.horizontal, PageLayoutKnobs.sideMargin)
        }

        .onGeometryChange(for: ScreenGeometry.self) {
            ScreenGeometry(safeSize: $0.size, safeAreaTop: $0.safeAreaInsets.top, safeAreaBottom: $0.safeAreaInsets.bottom, barHeight: barHeight)
        } action: {
            readerVM.screenChanged($0)
        }
        .task { await readerVM.onAppear() }
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
        .onReceive(NotificationCenter.default.publisher(for: UIAccessibility.announcementDidFinishNotification)) { event in
            guard let text = event.userInfo?[UIAccessibility.announcementStringValueUserInfoKey] as? String,
                  let finished = event.userInfo?[UIAccessibility.announcementWasSuccessfulUserInfoKey] as? Bool,
                  UIAccessibility.isVoiceOverRunning else { return }
            readerVM.passageSpeechEnded(text: text, finished: finished, isActive: scenePhase == .active)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIAccessibility.voiceOverStatusDidChangeNotification)) { _ in
            if UIAccessibility.isVoiceOverRunning { readerVM.replayPendingPassage() }
        }
        .onChange(of: readerVM.isFocusMode) {
            guard UIAccessibility.isVoiceOverRunning, let content = readerVM.pageContent else { return }
            let message = content.chrome(of: content.shownPage).readingModeDescription
            UIAccessibility.post(notification: .announcement, argument: NSAttributedString(
                string: message, attributes: [.accessibilitySpeechQueueAnnouncement: true]
            ))
        }
        .animation(.easeInOut, value: referenceVM.returnPrompt)
        .animation(.easeInOut(duration: 0.2), value: readerVM.isFocusMode)
        .onChange(of: scenePhase, initial: true) { _, scenePhase in
            if scenePhase == .background {
                readerVM.appBackgrounded()
            } else if scenePhase == .active {
                readerVM.appForegrounded()
                if UIAccessibility.isVoiceOverRunning { readerVM.replayPendingPassage() }
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
            case .characters:
                CharacterListSheet(characterVM: characterVM)
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
