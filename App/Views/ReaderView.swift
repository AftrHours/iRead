import SwiftUI

struct ReaderView: View {
    @State private var readerVM: ReaderVM
    @ScaledMetric(relativeTo: .body) private var bodyFontSize: CGFloat = 17
    @Environment(\.scenePhase) private var scenePhase

    init(readerVM: ReaderVM) {
        _readerVM = State(initialValue: readerVM)
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            GeometryReader { proxy in
                let viewport = Viewport(size: proxy.size, bodyFontSize: bodyFontSize)
                pageArea
                    .task { await readerVM.onAppear(viewport: viewport) }
                    .onChange(of: viewport) { _, viewport in readerVM.viewportChanged(viewport) }
            }
            .overlay(alignment: .bottom) {
                returnControls
            }
            .padding(.top, 36)
            .padding(.bottom, 24)
            bottomBar
        }
        .background(Color(.systemBackground))
        .animation(.easeInOut, value: readerVM.toastText)
        .onChange(of: scenePhase) { _, scenePhase in
            if scenePhase == .background {
                readerVM.appBackgrounded()
            }
        }
        .sheet(item: Binding(get: { readerVM.sheet }, set: { _ in readerVM.sheetDismissed() })) { sheet in
            switch sheet {
            case .contents:
                ContentsView(readerVM: readerVM)
            case .search(let searchVM):
                SearchView(searchVM: searchVM)
            case .themeSettings:
                ThemeSettingsView(readerVM: readerVM)
            case .symbolDetails:
                symbolDetails
            }
        }
    }

    @ViewBuilder
    private var pageArea: some View {
        if let shownPage = readerVM.shownPage {
            PageTurnView(
                pages: readerVM.pages,
                shownPage: shownPage,
                settings: readerVM.layoutSettings,
                bodyFontSize: readerVM.viewport.bodyFontSize,
                marks: readerVM.marks,
                onPageChanged: { readerVM.pageChanged($0) },
                onMarkTapped: { readerVM.markTapped($0, at: $1) }
            )
            .popover(
                item: Binding(get: { readerVM.card }, set: { _ in readerVM.cardDismissed() }),
                attachmentAnchor: .rect(.rect(readerVM.cardAnchor))
            ) { card in
                switch card {
                case .reference(let referenceCard):
                    RefCardView(card: referenceCard) { readerVM.jumpToPassageTapped() }
                case .symbol(let entity):
                    SymCardView(entity: entity) { readerVM.editSymbolTapped() }
                }
            }
        } else if readerVM.hasFailedToOpen {
            ContentUnavailableView("Can't Open Book", systemImage: "book.closed")
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var symbolDetails: some View {
        NavigationStack {
            Color.clear
                .navigationTitle("Symbol Details")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(role: .close) {
                            readerVM.sheetDismissed()
                        }
                    }
                }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color(.systemBackground))
    }

    @ViewBuilder
    private var returnControls: some View {
        if readerVM.canReturn {
            HStack(spacing: 12) {
                Button {
                    readerVM.returnDismissed()
                } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color(.systemGray2), in: .circle)
                }
                .accessibilityLabel("Dismiss")
                Button("Return to Reading", systemImage: "arrow.uturn.backward") {
                    readerVM.returnToReadingTapped()
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
            }
        } else if let toastText = readerVM.toastText {
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
            .padding(.horizontal, 64)
            HStack {
                Button {
                    readerVM.backTapped()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title3.weight(.medium))
                        .frame(width: 44, height: 44)
                        .glassEffect(.regular.interactive(), in: .circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 26)
    }

    private var bottomBar: some View {
        HStack {
            Text(readerVM.pageLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                readerVM.menuTapped()
            } label: {
                Image(systemName: "ellipsis")
                    .font(.title3.weight(.medium))
                    .frame(width: 44, height: 44)
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Reading menu")
            .popover(isPresented: Binding(get: { readerVM.isMenuShown }, set: { _ in readerVM.menuDismissed() }), arrowEdge: .bottom) {
                ReaderMenuView(readerVM: readerVM)
            }
        }
        .padding(.leading, 36)
        .padding(.trailing, 16)
        .padding(.bottom, 8)
    }
}
