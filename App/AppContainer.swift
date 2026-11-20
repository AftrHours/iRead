import Foundation

@MainActor
struct AppContainer {
    let appNav = AppNav()
    private let libRepo: LibRepo
    private let bookContentRepo: BookContentRepo
    private let underlineRepo: UnderlineRepo
    private let ratingRepo: RatingRepo
    private let progRepo: ProgRepo
    private let readingSettingsRepo: ReadingSettingsRepo
    private let bookStateRepo: BookStateRepo
    private let pagerSvc = PagerSvcTextKit()
    private let eventSvc = EventSvcOSLog()
    private let brightnessSvc = BrightnessSvc()
    private let pendingImportRepo: PendingImportRepo
    private let libraryIndexRepo: LibraryIndexRepo
    private let cloudSvc: (any CloudSvc)?

    /// A UI test (see AppFolders) runs on rules and the bundled seeds, in its own folders, with nothing sent to iCloud.
    init() {
//        self.init(modelCheckSvc: ModelCheckSvc(), cloudSvc: CloudSvcCloudKit())
        self.init(modelCheckSvc: AppFolders.isUITesting ? nil : ModelCheckSvc(), cloudSvc: nil, folders: .current)
    }

    static func forPreviews() -> AppContainer {
        AppContainer(modelCheckSvc: nil, cloudSvc: nil)
    }

    private init(modelCheckSvc: ModelCheckSvc?, cloudSvc: (any CloudSvc)?, folders: AppFolders = .standard) {
        let epubParseSvc = EPUBParseSvcEPUBKit()
        progRepo = ProgRepo(folder: folders.books)
        bookContentRepo = BookContentRepo(epubParseSvc: epubParseSvc, folder: folders.books)
        libRepo = LibRepo(epubParseSvc: epubParseSvc, folder: folders.books)
        underlineRepo = UnderlineRepo(folder: folders.underlines, seedFolder: Bundle.main.url(forResource: "UnderlineSeed", withExtension: nil),
                                      modelCheckSvc: modelCheckSvc, cloudSvc: cloudSvc, embedding: .contextual)
        ratingRepo = RatingRepo(folder: folders.settings, cloudSvc: cloudSvc)
        readingSettingsRepo = ReadingSettingsRepo(folder: folders.settings)
        bookStateRepo = BookStateRepo(folder: folders.books)
        pendingImportRepo = PendingImportRepo(folder: folders.pendingImports)
        libraryIndexRepo = LibraryIndexRepo(folder: folders.libraryIndex)
        self.cloudSvc = cloudSvc
    }

    func makeLibVM() -> LibVM {
        LibVM(
            libCtrl: LibCtrl(libRepo: libRepo, bookContentRepo: bookContentRepo, progRepo: progRepo),
            importCtrl: ImportCtrl(libRepo: libRepo, pendingImportRepo: pendingImportRepo, libraryIndexRepo: libraryIndexRepo),
            appNav: appNav,
            cloudSvc: cloudSvc
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

/// Isolated dependencies and fixture data for Xcode Canvas previews.
@MainActor
enum PreviewFixtures {
    static func libraryVM() -> LibVM {
        let folder = temporaryFolder()
        return libraryVM(folder: folder)
    }

    /// Extra sample copies in an isolated folder, so iPad previews have enough rows to scroll.
    static func scrollingLibraryVM() -> LibVM {
        let folder = temporaryFolder()
        let libRepo = LibRepo(epubParseSvc: EPUBParseSvcEPUBKit(), folder: folder)
        for _ in 0..<3 {
            for sample in BookRecord.samples {
                guard let url = Bundle.main.url(forResource: sample.fileName, withExtension: "epub") else { continue }
                let candidate = ImportCandidate(title: sample.book.title, author: sample.book.author, identity: sample.book.identity)
                _ = try? libRepo.saveBook(from: url, as: candidate)
            }
        }
        return libraryVM(folder: folder)
    }

    static func emptyLibraryVM() -> LibVM {
        let folder = temporaryFolder()
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let hiddenIDs = Set(BookRecord.samples.map { $0.book.id })
        try? JSONEncoder().encode(hiddenIDs).write(to: folder.appending(path: "hidden-samples.json"), options: .atomic)
        return libraryVM(folder: folder)
    }

    static func searchResultsVM() -> LibVM {
        let viewModel = libraryVM()
        viewModel.searchText = "Sunrise on the reaping"
        viewModel.searchTapped()
        return viewModel
    }

    private static func libraryVM(folder: URL) -> LibVM {
        let epubParseSvc = EPUBParseSvcEPUBKit()
        let progRepo = ProgRepo(folder: folder)
        let bookContentRepo = BookContentRepo(epubParseSvc: epubParseSvc, folder: folder)
        let libRepo = LibRepo(epubParseSvc: epubParseSvc, folder: folder)
        let libCtrl = LibCtrl(libRepo: libRepo, bookContentRepo: bookContentRepo, progRepo: progRepo)
        let importCtrl = ImportCtrl(libRepo: libRepo, pendingImportRepo: PendingImportRepo(folder: folder.appending(path: "PendingImports")),
                                    libraryIndexRepo: LibraryIndexRepo(folder: folder))
        return LibVM(libCtrl: libCtrl, importCtrl: importCtrl, appNav: AppNav())
    }

    static func onboardingVM() -> OnboardingVM {
        OnboardingVM { _ in true }
    }

    static func readerVM() -> ReaderVM {
        let folder = temporaryFolder()
        let book = BookRecord.samples[0].book
        let epubParseSvc = EPUBParseSvcEPUBKit()
        let bookContentRepo = BookContentRepo(epubParseSvc: epubParseSvc, folder: folder)
        let progRepo = ProgRepo(folder: folder)
        let readingSettingsRepo = ReadingSettingsRepo(folder: folder)
        let bookStateRepo = BookStateRepo(folder: folder)
        let readerStateCtrl = ReaderStateCtrl(
            bookID: book.id,
            readingSettingsRepo: readingSettingsRepo,
            brightnessSvc: BrightnessSvc(),
            bookStateRepo: bookStateRepo
        )
        let underlineRepo = UnderlineRepo(folder: folder.appending(path: "Underlines"))
        let ratingRepo = RatingRepo(folder: folder)
        let readerCtrl = ReaderCtrl(bookID: book.id, bookContentRepo: bookContentRepo, pagerSvc: PagerSvcTextKit())
        let readerVM = ReaderVM(
            book: book,
            readerCtrl: readerCtrl,
            progressCtrl: ProgressCtrl(bookID: book.id, progRepo: progRepo, eventSvc: EventSvcOSLog()),
            readerStateCtrl: readerStateCtrl,
            appNav: AppNav(),
            readerSettingsVM: ReaderSettingsVM(readerStateCtrl: readerStateCtrl),
            referenceVM: ReferenceVM(
                refCtrl: RefCtrl(bookID: book.id, bookContentRepo: bookContentRepo, underlineRepo: underlineRepo),
                readerStateCtrl: readerStateCtrl,
                readerCtrl: readerCtrl
            ),
            ratingVM: RatingVM(ratingCtrl: RatingCtrl(
                bookID: book.id,
                bookTitle: book.title,
                bookContentRepo: bookContentRepo,
                underlineRepo: underlineRepo,
                ratingRepo: ratingRepo
            ))
        )
        return readerVM
    }

    static func readerSettingsVM() -> ReaderSettingsVM {
        let folder = temporaryFolder()
        let stateCtrl = ReaderStateCtrl(
            bookID: BookRecord.samples[0].book.id,
            readingSettingsRepo: ReadingSettingsRepo(folder: folder),
            brightnessSvc: BrightnessSvc(),
            bookStateRepo: BookStateRepo(folder: folder)
        )
        return ReaderSettingsVM(readerStateCtrl: stateCtrl)
    }

    private static func temporaryFolder() -> URL {
        URL.temporaryDirectory.appending(path: "iRead-XcodePreview-\(UUID().uuidString)")
    }
}
