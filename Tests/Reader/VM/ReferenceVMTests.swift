import Foundation
import Testing
import UnderlineEngine
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
        let underline = Underline.make("the clock", paragraph: 2, passage: "The old clock stood in the hall for years.", passageParagraph: 0,
                                       in: content)
        try StoredUnderlines.write([underline], chapter: 0, of: sampleID, parserVersion: content.parserVersion, in: folder.url)

        let bookContentRepo = BookContentRepo(epubParseSvc: EPUBParseSvcSpy(content: content), folder: folder.url)
        let readerCtrl = ReaderCtrl(bookID: sampleID, bookContentRepo: bookContentRepo, pagerSvc: PagerSvcFixed(pageLength: 40))
        let readerStateCtrl = ReaderStateCtrl(bookID: sampleID, readingSettingsRepo: ReadingSettingsRepo(folder: folder.url),
                                              brightnessSvc: BrightnessSvc(), bookStateRepo: BookStateRepo(folder: folder.url))
        let refCtrl = RefCtrl(bookID: sampleID, bookContentRepo: bookContentRepo,
                              analysisRepo: .make(content: content, folder: folder.url), underlineRepo: UnderlineRepo(folder: folder.url))
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
        referenceVM.update(shownPage: readingPage, loadedPages: [readingPage], areSymbolsShown: false)

        referenceVM.markTapped(Mark(range: NSRange(), kind: .underline(id: underline.id)), at: .zero)
        #expect(await eventually { referenceVM.card != nil })
        referenceVM.jumpToPassageTapped()
        let jumped = try #require(await nextShown.next(isolation: MainActor.shared))
        #expect(jumped.underlineID == underline.id)
        #expect(jumped.page.range.location == 0)
        #expect(jumped.page != readingPage)
        #expect(await readerStateCtrl.returnPosition() == (await readerCtrl.startPosition(of: readingPage)))
        #expect(referenceVM.canReturn)

        referenceVM.update(shownPage: jumped.page, loadedPages: [jumped.page], areSymbolsShown: false)
        referenceVM.returnToReadingTapped()
        let returned = try #require(await nextShown.next(isolation: MainActor.shared))
        #expect(returned.page == readingPage)
        #expect(returned.underlineID == nil)
        #expect(await readerStateCtrl.returnPosition() == nil)
    }
}
