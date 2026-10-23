import SwiftUI

@main
struct iReadApp: App {
    @State private var appNav: AppNav
    @State private var libVM: LibVM
    private let libRepo: any LibRepo
    private let bookContentRepo: any BookContentRepo = BookContentRepoSample(epubParseSvc: EPUBParseSvcXML())
    private let pagerSvc: any PagerSvc = PagerSvcTextKit()

    init() {
        let appNav = AppNav()
        let libRepo = LibRepoSample()
        self.libRepo = libRepo
        _appNav = State(initialValue: appNav)
        _libVM = State(initialValue: LibVM(libCtrl: LibCtrlLive(libRepo: libRepo), nav: appNav))
    }

    var body: some Scene {
        WindowGroup {
            switch appNav.route {
            case .library:
                LibView(libVM: libVM)
            case .reader(let bookID):
                ReaderView(readerVM: ReaderVM(
                    readerCtrl: ReaderCtrlLive(bookID: bookID, libRepo: libRepo, bookContentRepo: bookContentRepo, pagerSvc: pagerSvc),
                    nav: appNav
                ))
            }
        }
    }
}
