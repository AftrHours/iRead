import Foundation
import Observation

@MainActor
@Observable
final class ReaderVM {
    enum Sheet: Identifiable {
        case contents

        var id: Self { self }
    }

    let settings = ReadingSettings()
    private(set) var title = ""
    private(set) var chapterTitles: [String] = []
    private(set) var pages: [Page] = []
    private(set) var shownPage: Page?
    private(set) var viewport = Viewport(size: .zero, bodyFontSize: 0)
    private(set) var hasFailedToOpen = false
    private(set) var isMenuShown = false
    private(set) var sheet: Sheet?

    private var chapterStartPages: [Int] = []
    private var pageCount: Int?
    private var requestedViewport = Viewport(size: .zero, bodyFontSize: 0)
    private let readerCtrl: any ReaderCtrl
    private let nav: any Nav

    var chapterTitle: String {
        shownPage.map { chapterTitles[$0.chapterIndex] } ?? ""
    }

    var pageLabel: String {
        guard let shownPage else { return "" }
        guard let pageCount else { return "Page \(shownPage.number)" }
        return "Page \(shownPage.number) of \(pageCount)"
    }

    init(readerCtrl: any ReaderCtrl, nav: any Nav) {
        self.readerCtrl = readerCtrl
        self.nav = nav
    }

    func startPageLabel(ofChapter index: Int) -> String {
        chapterStartPages.indices.contains(index) ? "\(chapterStartPages[index])" : ""
    }

    func onAppear(viewport: Viewport) async {
        requestedViewport = viewport
        do {
            title = try await readerCtrl.openBook().title
            chapterTitles = await readerCtrl.chapterTitles()
            await showCurrentPage()
        } catch {
            hasFailedToOpen = true
        }
    }

    func viewportChanged(_ viewport: Viewport) {
        requestedViewport = viewport
        guard shownPage != nil else { return }
        Task { await showCurrentPage() }
    }

    func pageChanged(_ page: Page) {
        show(page)
    }

    func backTapped() {
        Task {
            await readerCtrl.saveNow()
            nav.closeReader()
        }
    }

    func appBackgrounded() {
        Task { await readerCtrl.saveNow() }
    }

    func menuTapped() {
        isMenuShown = true
    }

    func menuDismissed() {
        isMenuShown = false
    }

    func contentsTapped() {
        isMenuShown = false
        sheet = .contents
    }

    func sheetDismissed() {
        sheet = nil
    }

    func chapterTapped(_ index: Int) {
        sheet = nil
        Task { show(await readerCtrl.firstPage(ofChapter: index)) }
    }

    private func showCurrentPage() async {
        let viewport = requestedViewport
        let page = await readerCtrl.currentPage(viewport: viewport)
        guard viewport == requestedViewport else { return }
        self.viewport = viewport
        shownPage = page
        pages = [page]
        loadPages(around: page)
        loadPageTotals()
    }

    private func show(_ page: Page) {
        shownPage = page
        loadPages(around: page)
        Task { await readerCtrl.pageChanged(to: page) }
    }

    private func loadPages(around page: Page) {
        Task {
            let pages = await readerCtrl.pages(around: page)
            guard shownPage == page else { return }
            self.pages = pages
        }
    }

    private func loadPageTotals() {
        chapterStartPages = []
        pageCount = nil
        Task {
            let counts = await readerCtrl.chapterPageCounts()
            chapterStartPages = counts.indices.map { index in counts[..<index].reduce(1, +) }
            pageCount = counts.reduce(0, +)
        }
    }
}
