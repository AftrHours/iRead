import SwiftUI

@main
struct iReadApp: App {
    @State private var appNav: AppNav
    @State private var libVM: LibVM
    private let libRepo: LibRepo
    private let bookContentRepo: BookContentRepo
    private let analysisRepo: AnalysisRepo
    private let progRepo = ProgRepo()
    private let readingSettingsRepo = ReadingSettingsRepo()
    private let bookStateRepo = BookStateRepo()
    private let pagerSvc = PagerSvc()
    private let eventSvc = EventSvc()
    private let brightnessSvc = BrightnessSvc()

    init() {
        let appNav = AppNav()
        let libRepo = LibRepo()
        let bookContentRepo = BookContentRepo(epubParseSvc: EPUBParseSvc())
        self.libRepo = libRepo
        self.bookContentRepo = bookContentRepo
        analysisRepo = AnalysisRepo(bookContentRepo: bookContentRepo, analysisScheduleSvc: AnalysisScheduleSvc())
        _appNav = State(initialValue: appNav)
        _libVM = State(initialValue: LibVM(libCtrl: LibCtrl(libRepo: libRepo), appNav: appNav))
    }

    var body: some Scene {
        WindowGroup {
            switch appNav.route {
            case .library:
                LibView(libVM: libVM)
            case .reader(let bookID):
                ReaderView(readerVM: ReaderVM(
                    readerCtrl: ReaderCtrl(
                        bookID: bookID,
                        libRepo: libRepo,
                        bookContentRepo: bookContentRepo,
                        pagerSvc: pagerSvc,
                        progRepo: progRepo,
                        eventSvc: eventSvc,
                        readingSettingsRepo: readingSettingsRepo,
                        brightnessSvc: brightnessSvc,
                        bookStateRepo: bookStateRepo
                    ),
                    refCtrl: RefCtrl(bookID: bookID, bookContentRepo: bookContentRepo, analysisRepo: analysisRepo),
                    appNav: appNav
                ))
            }
        }
    }
}
