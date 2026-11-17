import Foundation
import Testing
@testable import iRead

@MainActor
@Suite("ReaderVM")
struct ReaderVMTests {
    private let folder = TempFolder()
    private let content = BookContent.make(chapters: [["The old clock stood in the hall.", "Then Anna looked at the clock again."]])
    private let phone = ScreenGeometry(safeSize: CGSize(width: 440, height: 860), safeAreaTop: 62, safeAreaBottom: 34)

    private func makeVM() -> ReaderVM {
        let book = BookRecord.samples[0].book
        let bookContentRepo = BookContentRepo(epubParseSvc: EPUBParseSvcSpy(content: content), folder: folder.url)
        let underlineRepo = UnderlineRepo(folder: folder.url)
        let readerCtrl = ReaderCtrl(bookID: book.id, bookContentRepo: bookContentRepo, pagerSvc: PagerSvcFixed(pageLength: 40))
        let readerStateCtrl = ReaderStateCtrl(bookID: book.id, readingSettingsRepo: ReadingSettingsRepo(folder: folder.url),
                                              brightnessSvc: BrightnessSvc(), bookStateRepo: BookStateRepo(folder: folder.url))
        return ReaderVM(
            book: book,
            readerCtrl: readerCtrl,
            progressCtrl: ProgressCtrl(bookID: book.id, progRepo: ProgRepo(folder: folder.url), eventSvc: EventSvcSpy()),
            readerStateCtrl: readerStateCtrl,
            appNav: AppNav(),
            readerSettingsVM: ReaderSettingsVM(readerStateCtrl: readerStateCtrl),
            referenceVM: ReferenceVM(refCtrl: RefCtrl(bookID: book.id, bookContentRepo: bookContentRepo, underlineRepo: underlineRepo),
                                     readerStateCtrl: readerStateCtrl, readerCtrl: readerCtrl),
            ratingVM: RatingVM(ratingCtrl: RatingCtrl(bookID: book.id, bookTitle: book.title, bookContentRepo: bookContentRepo,
                                                      underlineRepo: underlineRepo, ratingRepo: RatingRepo(folder: folder.url)))
        )
    }

    @Test("RD-45 the pages' layout comes from the measured screen, and there is no page content before it")
    func layoutFromScreen() {
        let readerVM = makeVM()
        #expect(readerVM.layout == nil)
        #expect(readerVM.pageContent == nil)
        readerVM.screenChanged(phone)
        #expect(readerVM.layout == PageLayout(phone))
        // There is still no page: the book hasn't been opened.
        #expect(readerVM.pageContent == nil)
    }

    @Test("RD-46 on a full-width screen the settings are a panel, not a sheet; on a narrow one they are a sheet")
    func settingsPanelOrSheet() {
        let readerVM = makeVM()
        readerVM.widthClassChanged(isRegular: false)
        readerVM.themeSettingsTapped()
        #expect(!readerVM.isSettingsPanelShown)
        guard case .themeSettings = readerVM.presentedSheet else {
            Issue.record("A narrow screen presents the settings as a sheet")
            return
        }

        readerVM.widthClassChanged(isRegular: true)
        #expect(readerVM.isSettingsPanelShown)
        #expect(readerVM.presentedSheet == nil)

        // Setting the sheet to nil, as dismissing it does, closes the settings.
        readerVM.widthClassChanged(isRegular: false)
        readerVM.presentedSheet = nil
        #expect(readerVM.sheet == nil)
        #expect(!readerVM.isSettingsPanelShown)
    }

    @Test("RD-48 the reference card is the iPhone's on a narrow screen and the iPad's on a full-width one")
    func cardSize() {
        let readerVM = makeVM()
        readerVM.widthClassChanged(isRegular: false)
        #expect(!readerVM.isCardForPad)
        readerVM.widthClassChanged(isRegular: true)
        #expect(readerVM.isCardForPad)
    }

    @Test("RD-47 the page is dark when the device is, in Match Device")
    func darkPage() {
        let readerVM = makeVM()
        #expect(readerVM.forcedDarkMode == nil)
        #expect(!readerVM.isDarkPage)
        readerVM.systemAppearanceChanged(isDark: true)
        #expect(readerVM.isDarkPage)
    }
}
