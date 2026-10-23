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
            .padding(.top, 36)
            .padding(.bottom, 24)
            bottomBar
        }
        .background(Color(.systemBackground))
        .onChange(of: scenePhase) { _, scenePhase in
            if scenePhase == .background {
                readerVM.appBackgrounded()
            }
        }
    }

    @ViewBuilder
    private var pageArea: some View {
        if let shownPage = readerVM.shownPage {
            PageTurnView(
                pages: readerVM.pages,
                shownPage: shownPage,
                settings: readerVM.settings,
                bodyFontSize: readerVM.viewport.bodyFontSize,
                onPageChanged: { readerVM.pageChanged($0) }
            )
        } else if readerVM.hasFailedToOpen {
            ContentUnavailableView("Can't Open Book", systemImage: "book.closed")
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        }
        .frame(height: 44)
        .padding(.horizontal, 36)
        .padding(.bottom, 8)
    }
}
