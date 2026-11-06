import Foundation
import Testing
@testable import iRead

@Suite("ReferenceVM")
@MainActor
struct ReferenceVMTests {
    private let folder = TempFolder()

    @Test("RD-23 jumping to a passage saves where the reader was; returning goes back there and clears it", .timeLimit(.minutes(1)))
    func jumpAndReturn() async throws {
        let content = BookContent.make(chapters: [[
            "The old clock stood in the hall for years.",
            "Nobody wound it, and nobody asked why it stopped.",
            "Then Anna looked at the clock again."
        ]])
        let underline = SavedUnderline.make("the clock", paragraph: 2, passage: "The old clock stood in the hall for years.",
                                            passageParagraph: 0, in: content)
        try StoredUnderlines.write([underline], chapter: 0, of: content.fingerprint, parserVersion: content.parserVersion, in: folder.url)

        let bookContentRepo = BookContentRepo(epubParseSvc: EPUBParseSvcSpy(content: content), folder: folder.url)
        let readerCtrl = ReaderCtrl(bookID: sampleID, bookContentRepo: bookContentRepo, pagerSvc: PagerSvcFixed(pageLength: 40))
        let readerStateCtrl = ReaderStateCtrl(bookID: sampleID, readingSettingsRepo: ReadingSettingsRepo(folder: folder.url),
                                              brightnessSvc: BrightnessSvc(), bookStateRepo: BookStateRepo(folder: folder.url))
        let refCtrl = RefCtrl(bookID: sampleID, bookContentRepo: bookContentRepo, underlineRepo: UnderlineRepo(folder: folder.url))
        let referenceVM = ReferenceVM(refCtrl: refCtrl, readerStateCtrl: readerStateCtrl, readerCtrl: readerCtrl)

        try await readerCtrl.openBook()
        _ = await readerCtrl.restorePosition(from: .make(paragraph: 2, charOffset: 5))
        let readingPage = await readerCtrl.currentPage(viewport: iPadViewport, settings: ReadingSettings())
        // Loads the stored chapter, as showing the page does.
        for await _ in try await refCtrl.underlineUpdates(from: readingPage) {}
        await referenceVM.bookOpened()

        let (shownPages, shown) = AsyncStream<(page: Page, underlineID: String?)>.makeStream()
        referenceVM.onShowPage = { shown.yield(($0, $1)) }
        var nextShown = shownPages.makeAsyncIterator()
        referenceVM.update(shownPage: readingPage, loadedPages: [readingPage])

        referenceVM.markTapped(Mark(range: NSRange(), kind: .underline(id: underline.id)), at: .zero)
        #expect(await eventually { referenceVM.card != nil })
        referenceVM.jumpToPassageTapped()
        let jumped = try #require(await nextShown.next(isolation: MainActor.shared))
        #expect(jumped.underlineID == underline.id)
        #expect(jumped.page.range.location == 0)
        #expect(jumped.page != readingPage)
        #expect(await readerStateCtrl.returnPosition() == (await readerCtrl.startPosition(of: readingPage)))
        #expect(referenceVM.canReturn)

        referenceVM.update(shownPage: jumped.page, loadedPages: [jumped.page])
        referenceVM.returnToReadingTapped()
        let returned = try #require(await nextShown.next(isolation: MainActor.shared))
        #expect(returned.page == readingPage)
        #expect(returned.underlineID == nil)
        #expect(await readerStateCtrl.returnPosition() == nil)
    }

    @Test("RD-24 closing the reader cancels the chapter's underlining for good, and lets the ReferenceVM go", .timeLimit(.minutes(1)))
    func closeStopsUnderlining() async throws {
        let content = BookContent.make(chapters: [["Anna opened the old box. Inside lay a silver key.", "She took the key to the door."]])
        let bookContentRepo = BookContentRepo(epubParseSvc: EPUBParseSvcSpy(content: content), folder: folder.url)
        let readerCtrl = ReaderCtrl(bookID: sampleID, bookContentRepo: bookContentRepo, pagerSvc: PagerSvcFixed(pageLength: 40))
        let readerStateCtrl = ReaderStateCtrl(bookID: sampleID, readingSettingsRepo: ReadingSettingsRepo(folder: folder.url),
                                              brightnessSvc: BrightnessSvc(), bookStateRepo: BookStateRepo(folder: folder.url))
        let refCtrl = RefCtrl(bookID: sampleID, bookContentRepo: bookContentRepo, underlineRepo: UnderlineRepo(folder: folder.url))
        try await readerCtrl.openBook()
        let page = await readerCtrl.currentPage(viewport: iPadViewport, settings: ReadingSettings())

        weak var releasedVM: ReferenceVM?
        do {
            let referenceVM = ReferenceVM(refCtrl: refCtrl, readerStateCtrl: readerStateCtrl, readerCtrl: readerCtrl)
            releasedVM = referenceVM
            referenceVM.update(shownPage: page, loadedPages: [page])
            let underlineTask = try #require(referenceVM.underlineTask)

            referenceVM.close()
            #expect(underlineTask.isCancelled)
            // Showing a page, or coming back to the app, after closing doesn't start underlining again.
            referenceVM.update(shownPage: page, loadedPages: [page])
            referenceVM.appForegrounded()
            #expect(referenceVM.underlineTask == underlineTask)
        }
        #expect(await eventually { releasedVM == nil })
    }
}
