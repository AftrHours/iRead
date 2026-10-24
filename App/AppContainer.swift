import Foundation

@MainActor
struct AppContainer {
    let appNav = AppNav()
    private let libRepo: LibRepo
    private let bookContentRepo: BookContentRepo
    private let analysisRepo: AnalysisRepo
    private let progRepo: ProgRepo
    private let readingSettingsRepo = ReadingSettingsRepo()
    private let bookStateRepo = BookStateRepo()
    private let pagerSvc = PagerSvc()
    private let eventSvc = EventSvc()
    private let brightnessSvc = BrightnessSvc()

    init() {
        let epubParseSvc = EPUBParseSvc()
        let progRepo = ProgRepo()
        let bookContentRepo = BookContentRepo(epubParseSvc: epubParseSvc)
        self.progRepo = progRepo
        self.bookContentRepo = bookContentRepo
        libRepo = LibRepo(epubParseSvc: epubParseSvc, progRepo: progRepo)
        analysisRepo = AnalysisRepo(bookContentRepo: bookContentRepo, analysisScheduleSvc: AnalysisScheduleSvc())
    }

    func makeLibVM() -> LibVM {
        LibVM(libCtrl: LibCtrl(libRepo: libRepo), appNav: appNav)
    }

    func makeReaderVM(book: BookRecord) -> ReaderVM {
        let readerCtrl = ReaderCtrl(bookID: book.id, bookContentRepo: bookContentRepo, pagerSvc: pagerSvc)
        let readerStateCtrl = ReaderStateCtrl(
            bookID: book.id,
            readingSettingsRepo: readingSettingsRepo,
            brightnessSvc: brightnessSvc,
            bookStateRepo: bookStateRepo
        )
        return ReaderVM(
            book: book,
            readerCtrl: readerCtrl,
            progressCtrl: ProgressCtrl(bookID: book.id, progRepo: progRepo, eventSvc: eventSvc),
            appNav: appNav,
            readerSettingsVM: ReaderSettingsVM(readerStateCtrl: readerStateCtrl),
            referenceVM: ReferenceVM(
                refCtrl: RefCtrl(bookID: book.id, bookContentRepo: bookContentRepo, analysisRepo: analysisRepo),
                readerStateCtrl: readerStateCtrl,
                readerCtrl: readerCtrl
            )
        )
    }
}
