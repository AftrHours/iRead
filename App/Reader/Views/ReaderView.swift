import SwiftUI

struct ReaderView: View {
    @Bindable private var readerVM: ReaderVM
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme

    private let readerSettingsVM: ReaderSettingsVM
    private let referenceVM: ReferenceVM
    private let ratingVM: RatingVM
    private var theme: ReadingTheme { readerSettingsVM.layoutSettings.theme }
    // Only the page's own text uses the theme colour. Set on the whole view, it would leak into
    // the menu and sheets, which follow the system light or dark mode instead.
    private var pageTextColor: Color { Color(PageTextStyle.textColor(for: theme)) }
    /// Original follows the system; the other themes have a fixed light or dark page.
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
        ratingVM = readerVM.ratingVM
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            GeometryReader { proxy in
                let viewport = Viewport(size: proxy.size)
                pageArea
                    .task { await readerVM.onAppear(viewport: viewport) }
                    .onChange(of: viewport) { _, viewport in readerVM.viewportChanged(viewport) }
            }
            .padding(.top, 36)
            // Always kept free, so the text never moves or hides under the Return to Reading button.
            Color.clear
                .frame(height: 44)
                .overlay { returnControls }
                .padding(.vertical, 12)
            bottomBar
        }
        .background(Color(PageTextStyle.backgroundColor(for: theme)))
        .animation(.easeInOut, value: referenceVM.toastText)
        .animation(.easeInOut(duration: 0.2), value: readerVM.areControlsShown)
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
                ContentsView(readerVM: readerVM)
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

    @ViewBuilder
    private var pageArea: some View {
        if let shownPage = readerVM.shownPage {
            PageTurnView(
                pages: readerVM.pages,
                shownPage: shownPage,
                settings: readerSettingsVM.layoutSettings,
                marks: referenceVM.marks,
                onPageChanged: { readerVM.pageChanged($0) },
                onCenterTapped: { readerVM.pageCenterTapped() },
                onMarkTapped: { referenceVM.markTapped($0, at: $1) }
            )
            .id(readerSettingsVM.layoutSettings.pageTurnStyle)
            .popover(
                item: Binding(get: { referenceVM.card }, set: { _ in referenceVM.cardDismissed() }),
                attachmentAnchor: .rect(.rect(referenceVM.cardAnchor))
            ) { referenceCard in
                RefCardView(card: referenceCard, ratingVM: ratingVM, onJumpTapped: { referenceVM.jumpToPassageTapped() })
            }
        } else if readerVM.hasFailedToOpen {
            ContentUnavailableView("Can't Open Book", systemImage: "book.closed")
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private var returnControls: some View {
        if referenceVM.canReturn {
            HStack(spacing: 12) {
                Button {
                    referenceVM.returnDismissed()
                } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color(.systemGray2), in: .circle)
                }
                .accessibilityLabel("Dismiss")
                Button("Return to Reading", systemImage: "arrow.uturn.backward") {
                    referenceVM.returnToReadingTapped()
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
            }
        } else if let toastText = referenceVM.toastText {
            Text(toastText)
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .frame(minHeight: 44)
                .background(Color(.systemGray2), in: .capsule)
                .transition(.opacity)
        }
    }

    private var topBar: some View {
        ZStack {
            VStack(spacing: 6) {
                Text(readerVM.title)
                    .font(.subheadline.weight(.semibold))
                Text(readerVM.chapterTitle)
                    .font(.caption2)
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
            .foregroundStyle(pageTextColor)
            .padding(.horizontal, 64)
            HStack {
                ReaderCircleButton(
                    systemImage: "chevron.left",
                    accessibilityLabel: "Back",
                    foreground: pageTextColor,
                    colorScheme: pageColorScheme,
                    isVisible: readerVM.areControlsShown,
                    action: readerVM.backTapped
                )
                Spacer()
                #if DEBUG
                ReaderCircleButton(
                    systemImage: "ladybug",
                    accessibilityLabel: "Underline Debug",
                    foreground: pageTextColor,
                    colorScheme: pageColorScheme,
                    isVisible: readerVM.areControlsShown,
                    action: readerVM.underlineDebugTapped
                )
                .keyboardShortcut("d", modifiers: [.command, .shift])
                #endif
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 26)
    }

    private var bottomBar: some View {
        HStack {
            Text(readerVM.pageLabel)
                .font(.caption)
                .foregroundStyle(pageTextColor)
            Spacer()
            ReaderCircleButton(
                systemImage: "ellipsis",
                accessibilityLabel: "Reading menu",
                foreground: pageTextColor,
                colorScheme: pageColorScheme,
                isVisible: readerVM.areControlsShown,
                action: readerVM.menuTapped
            )
            .popover(isPresented: Binding(get: { readerVM.isMenuShown }, set: { _ in readerVM.menuDismissed() }), arrowEdge: .bottom) {
                ReaderMenuView(readerVM: readerVM, ratingVM: ratingVM)
                    .onDisappear { readerVM.menuDisappeared() }
            }
        }
        .padding(.leading, 36)
        .padding(.trailing, 16)
        .padding(.bottom, 8)
    }

}

#Preview("Reader") {
    ReaderView(readerVM: PreviewFixtures.readerVM())
}
