import Foundation

@MainActor
struct AppContainer {
    let appNav = AppNav()
    private let libRepo: LibRepo
    private let bookContentRepo: BookContentRepo
    private let underlineRepo: UnderlineRepo
    private let ratingRepo: RatingRepo
    private let progRepo: ProgRepo
    private let readingSettingsRepo = ReadingSettingsRepo()
    private let bookStateRepo = BookStateRepo()
    private let pagerSvc = PagerSvcTextKit()
    private let eventSvc = EventSvcOSLog()
    private let brightnessSvc = BrightnessSvc()
    private let pendingImportRepo = PendingImportRepo()
    private let libraryIndexRepo = LibraryIndexRepo()

    init() {
        let epubParseSvc = EPUBParseSvcEPUBKit()
        progRepo = ProgRepo()
        bookContentRepo = BookContentRepo(epubParseSvc: epubParseSvc)
        libRepo = LibRepo(epubParseSvc: epubParseSvc)
        let cloudSvc = CloudSvcCloudKit()
        underlineRepo = UnderlineRepo(modelCheckSvc: ModelCheckSvc(), cloudSvc: cloudSvc)
        ratingRepo = RatingRepo(cloudSvc: cloudSvc)
    }

    func makeLibVM() -> LibVM {
        LibVM(
            libCtrl: LibCtrl(libRepo: libRepo, bookContentRepo: bookContentRepo, progRepo: progRepo),
            importCtrl: ImportCtrl(libRepo: libRepo, pendingImportRepo: pendingImportRepo, libraryIndexRepo: libraryIndexRepo),
            appNav: appNav
        )
    }

    func makeOnboardingVM(using libVM: LibVM) -> OnboardingVM {
        OnboardingVM { urls in await libVM.importFiles(.success(urls)) }
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
                refCtrl: RefCtrl(bookID: book.id, bookContentRepo: bookContentRepo, underlineRepo: underlineRepo),
                readerStateCtrl: readerStateCtrl,
                readerCtrl: readerCtrl
            ),
            ratingVM: RatingVM(ratingCtrl: RatingCtrl(bookID: book.id, bookTitle: book.title, bookContentRepo: bookContentRepo,
                                                      underlineRepo: underlineRepo, ratingRepo: ratingRepo))
        )
    }
}
