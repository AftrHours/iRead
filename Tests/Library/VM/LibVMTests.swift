import Foundation
import Testing
@testable import iRead

@Suite("LibVM")
@MainActor
struct LibVMTests {
    private let folder = TempFolder()

    @Test("LIB-16 an imported book stays first until the sort changes")
    func importedBookPinnedUntilSortChanges() async throws {
        let books = folder.url.appending(path: "Books")
        let epubParseSvc = EPUBParseSvcEPUBKit()
        let libRepo = LibRepo(epubParseSvc: epubParseSvc, folder: books)
        let libCtrl = LibCtrl(
            libRepo: libRepo,
            bookContentRepo: BookContentRepo(epubParseSvc: epubParseSvc, folder: books),
            progRepo: ProgRepo(folder: books)
        )
        let importCtrl = ImportCtrl(libRepo: libRepo,
                                    pendingImportRepo: PendingImportRepo(folder: folder.url.appending(path: "PendingImports")),
                                    libraryIndexRepo: LibraryIndexRepo(folder: folder.url))
        let libVM = LibVM(libCtrl: libCtrl, importCtrl: importCtrl, appNav: AppNav())
        await libVM.onAppear()

        await libVM.importFiles(.success([try Fixture.url("minimal")]))
        let imported = try #require(libVM.books.first)
        #expect(imported.title == "Minimal Book")

        libVM.sortChanged(.title)
        let titleOrder = LibrarySorter.sorted(libVM.books, by: .title, pinning: nil)
        #expect(libVM.books.map(\.id) == titleOrder.map(\.id))
        #expect(libVM.books.first?.id != imported.id)
    }
}
