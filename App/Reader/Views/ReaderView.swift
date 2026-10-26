import SwiftUI

struct ReaderView: View {
    @State private var readerVM: ReaderVM
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    #if DEBUG
    @State private var isEngineDebugShown = false
    #endif

    private var readerSettingsVM: ReaderSettingsVM { readerVM.readerSettingsVM }
    private var referenceVM: ReferenceVM { readerVM.referenceVM }
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
        _readerVM = State(initialValue: readerVM)
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
            case .chapterSymbols:
                ChapterSymbolsView(referenceVM: referenceVM)
            case .editSymbol(let entity):
                EditSymbolView(entity: entity, style: referenceVM.symbolStyle(for: entity)) { style in
                    referenceVM.symbolSaved(style, for: entity)
                }
            }
        }
        #if DEBUG
        .sheet(isPresented: $isEngineDebugShown) {
            EngineDebugView(engineDebugVM: referenceVM.makeEngineDebugVM())
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
            .popover(
                item: Binding(get: { referenceVM.card }, set: { _ in referenceVM.cardDismissed() }),
                attachmentAnchor: .rect(.rect(referenceVM.cardAnchor))
            ) { card in
                Group {
                    switch card {
                    case .reference(let referenceCard):
                        RefCardView(card: referenceCard) { referenceVM.jumpToPassageTapped() }
                    case .symbol(let symbolCard):
                        SymCardView(card: symbolCard, style: referenceVM.symbolStyle(for: symbolCard.entity)) {
                            referenceVM.editSymbolTapped(symbolCard.entity)
                        }
                    }
                }
                .onDisappear { referenceVM.cardDisappeared() }
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

    #if DEBUG
    private var engineDebugLabel: some View {
        Group {
            if referenceVM.isEngineRunning {
                ProgressView()
            } else {
                Image(systemName: "ladybug")
                    .font(.title3.weight(.medium))
                    .overlay(alignment: .topTrailing) {
                        Circle()
                            .fill(.green)
                            .frame(width: 8, height: 8)
                            .offset(x: 4, y: -4)
                    }
            }
        }
        .frame(width: 44, height: 44)
        .contentShape(.circle)
        .glassEffect(.regular.interactive(), in: .circle)
    }
    #endif

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
                circleButton(systemImage: "chevron.left", label: "Back") {
                    readerVM.backTapped()
                }
                Spacer()
                #if DEBUG
                Button {
                    isEngineDebugShown = true
                } label: {
                    engineDebugLabel
                }
                .buttonStyle(.plain)
                .keyboardShortcut("d", modifiers: [.command, .shift])
                .accessibilityLabel("Engine Debug")
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
            circleButton(systemImage: "ellipsis", label: "Reading menu") {
                readerVM.menuTapped()
            }
            .popover(isPresented: Binding(get: { readerVM.isMenuShown }, set: { _ in readerVM.menuDismissed() }), arrowEdge: .bottom) {
                ReaderMenuView(readerVM: readerVM, readerSettingsVM: readerSettingsVM)
                    .onDisappear { readerVM.menuDisappeared() }
            }
        }
        .padding(.leading, 36)
        .padding(.trailing, 16)
        .padding(.bottom, 8)
    }

    /// Hidden but still taking up space while the controls are hidden, so the page never moves.
    private func circleButton(systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title3.weight(.medium))
                .foregroundStyle(pageTextColor)
                .frame(width: 44, height: 44)
                // The whole circle is tappable, not only the icon.
                .contentShape(.circle)
                .glassEffect(.regular.interactive(), in: .circle)
                // Set inside the label, so the menu popover keeps the system mode.
                .environment(\.colorScheme, pageColorScheme)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .opacity(readerVM.areControlsShown ? 1 : 0)
        .allowsHitTesting(readerVM.areControlsShown)
        .accessibilityHidden(!readerVM.areControlsShown)
    }
}
