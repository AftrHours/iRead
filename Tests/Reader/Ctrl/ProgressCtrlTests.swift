import Foundation
import Testing
@testable import iRead

@Suite("ProgressCtrl")
struct ProgressCtrlTests {
    private let folder = TempFolder()
    private let bookID = UUID()
    private let finishedAt = Date(timeIntervalSince1970: 1_700_000_000)

    @Test("PR-13 reaching the last page twice logs bookFinished once")
    func finishedOnce() async {
        let spy = EventSvcSpy()
        let ctrl = ProgressCtrl(bookID: bookID, progRepo: ProgRepo(folder: folder.url), eventSvc: spy)
        await ctrl.pageRead(.make(bookID: bookID, progress: 1, finishedAt: finishedAt))
        await ctrl.pageRead(.make(bookID: bookID, progress: 1, finishedAt: finishedAt))
        // Writes the debounced save now, before the temp folder goes away.
        await ctrl.saveNow()
        #expect(spy.finishedCount == 1)
    }

    @Test("PR-14 a book finished before opening logs no bookFinished")
    func alreadyFinished() async {
        let spy = EventSvcSpy()
        let progRepo = ProgRepo(folder: folder.url)
        await progRepo.saveNow(.make(bookID: bookID, progress: 1, finishedAt: finishedAt))
        let ctrl = ProgressCtrl(bookID: bookID, progRepo: progRepo, eventSvc: spy)
        _ = await ctrl.savedProgress()
        await ctrl.pageRead(.make(bookID: bookID, progress: 1, finishedAt: finishedAt))
        await ctrl.saveNow()
        #expect(spy.finishedCount == 0)
    }

    @Test("PR-15 saveNow before any page is read writes nothing")
    func saveNowBeforeReading() async throws {
        let ctrl = ProgressCtrl(bookID: bookID, progRepo: ProgRepo(folder: folder.url), eventSvc: EventSvcSpy())
        await ctrl.saveNow()
        #expect(try FileManager.default.contentsOfDirectory(atPath: folder.url.path).isEmpty)
    }
}
