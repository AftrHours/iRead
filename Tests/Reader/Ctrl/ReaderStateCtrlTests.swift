import Foundation
import Testing
@testable import iRead

@Suite("ReaderStateCtrl")
struct ReaderStateCtrlTests {
    private let folder = TempFolder()
    private let bookID = UUID()

    /// A fresh Ctrl on the same folder, like opening the book again.
    private func makeCtrl(bookID: UUID? = nil) async -> ReaderStateCtrl {
        let ctrl = ReaderStateCtrl(bookID: bookID ?? self.bookID, readingSettingsRepo: ReadingSettingsRepo(folder: folder.url),
                                   brightnessSvc: BrightnessSvc(), bookStateRepo: BookStateRepo(folder: folder.url))
        await ctrl.load()
        return ctrl
    }

    @Test("RD-17 a repeated search moves to the front, whatever its case")
    func recentsDeduplicated() async {
        let ctrl = await makeCtrl()
        for query in ["Darcy", "bingley", "darcy"] {
            await ctrl.saveRecentSearch(query)
        }
        #expect(await ctrl.recentSearches() == ["darcy", "bingley"])
    }

    @Test("RD-18 only the 10 newest searches are kept, and clearing empties them")
    func recentsLimited() async {
        let ctrl = await makeCtrl()
        for number in 1...12 {
            await ctrl.saveRecentSearch("query \(number)")
        }
        #expect(await ctrl.recentSearches() == (3...12).reversed().map { "query \($0)" })
        await ctrl.clearRecentSearches()
        #expect(await ctrl.recentSearches().isEmpty)
        #expect(await makeCtrl().recentSearches().isEmpty)
    }

    @Test("RD-19 the first return position is kept, survives a reload, and clear removes it")
    func returnPosition() async {
        let first = ReadingPosition(paragraph: 3, charOffset: 4)
        let ctrl = await makeCtrl()
        await ctrl.saveReturnPosition(first)
        await ctrl.saveReturnPosition(ReadingPosition(paragraph: 9, charOffset: 0))
        #expect(await ctrl.returnPosition() == first)

        let reloaded = await makeCtrl()
        #expect(await reloaded.returnPosition() == first)
        await reloaded.clearReturnPosition()
        #expect(await reloaded.returnPosition() == nil)
        #expect(await makeCtrl().returnPosition() == nil)
    }

}
