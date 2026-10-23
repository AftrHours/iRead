import Foundation
import Observation

@MainActor
@Observable
final class ReaderVM {
    let settings = ReadingSettings()
    private(set) var title = ""
    private(set) var pages: [Page] = []
    private(set) var shownPage: Page?
    private(set) var viewport = Viewport(size: .zero, bodyFontSize: 0)
    private(set) var hasFailedToOpen = false

    private var chapterTitles: [String] = []
    private var requestedViewport = Viewport(size: .zero, bodyFontSize: 0)
    private let readerCtrl: any ReaderCtrl
    private let nav: any Nav

    var chapterTitle: String {
        shownPage.map { chapterTitles[$0.chapterIndex] } ?? ""
    }

    var pageLabel: String {
        shownPage.map { "Page \($0.number)" } ?? ""
    }

    init(readerCtrl: any ReaderCtrl, nav: any Nav) {
        self.readerCtrl = readerCtrl
        self.nav = nav
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
        shownPage = page
        loadPages(around: page)
        Task { await readerCtrl.pageChanged(to: page) }
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

    private func showCurrentPage() async {
        let viewport = requestedViewport
        let page = await readerCtrl.currentPage(viewport: viewport)
        guard viewport == requestedViewport else { return }
        self.viewport = viewport
        shownPage = page
        pages = [page]
        loadPages(around: page)
    }

    private func loadPages(around page: Page) {
        Task {
            let pages = await readerCtrl.pages(around: page)
            guard shownPage == page else { return }
            self.pages = pages
        }
    }
}
