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
        analysisRepo = AnalysisRepo(
            content: { [bookContentRepo] in try await bookContentRepo.content(for: $0) },
            prepassSvc: BookPrepassSvc(),
            chapterSvc: ChapterAnalysisSvc(),
            store: ChapterAnalysisStore(root: URL.applicationSupportDirectory.appending(path: "Books")),
            makeLLM: { ModelAvailSvc().makeLLMSvc() }
        )
    }

    func makeLibVM() -> LibVM {
        LibVM(libCtrl: LibCtrl(libRepo: libRepo, bookContentRepo: bookContentRepo), appNav: appNav)
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
            readerStateCtrl: readerStateCtrl,
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
