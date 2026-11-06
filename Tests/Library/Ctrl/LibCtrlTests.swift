import Foundation
import Testing
@testable import iRead

@Suite("LibCtrl")
struct LibCtrlTests {
    private let folder = TempFolder()
    private var books: URL { folder.url.appending(path: "Books") }

    private func makeLibCtrl() -> LibCtrl {
        let epubParseSvc = EPUBParseSvcEPUBKit()
        return LibCtrl(libRepo: LibRepo(epubParseSvc: epubParseSvc, folder: books),
                       bookContentRepo: BookContentRepo(epubParseSvc: epubParseSvc, folder: books), progRepo: ProgRepo(folder: books))
    }

    @Test("LIB-08 a finished book shows as fully read, with lastReadAt from its progress file")
    func finishedShowsFull() async throws {
        let libCtrl = makeLibCtrl()
        let readAt = Date(timeIntervalSince1970: 1_700_000_000)
        await libCtrl.progRepo.saveNow(.make(bookID: sampleID, progress: 0.4, lastReadAt: readAt, finishedAt: readAt))
        let book = try #require(try await libCtrl.loadLibrary().first { $0.id == sampleID })
        #expect(book.progress == 1)
        #expect(book.lastReadAt == readAt)
    }

    @Test("LIB-17 mark finished, then still reading, keeps the saved progress and position")
    func finishedThenStillReading() async throws {
        let libCtrl = makeLibCtrl()
        await libCtrl.progRepo.saveNow(.make(bookID: sampleID, paragraph: 12, charOffset: 3, progress: 0.4))
        let sample = BookRecord.samples[0].book

        await libCtrl.setFinished(true, for: sample)
        #expect(try await libCtrl.loadLibrary().first { $0.id == sampleID }?.progress == 1)

        await libCtrl.setFinished(false, for: sample)
        #expect(try await libCtrl.loadLibrary().first { $0.id == sampleID }?.progress == 0.4)
        #expect(await libCtrl.progRepo.progress(for: sampleID)?.position == ReadingPosition(paragraph: 12, charOffset: 3))
    }

    @Test("LIB-19 books with no saved progress keep their own; LibRepo itself never reads progress")
    func noSavedProgress() async throws {
        let libCtrl = makeLibCtrl()
        let imported = try await libCtrl.importBook(from: Fixture.url("minimal"))
        await libCtrl.progRepo.saveNow(.make(bookID: sampleID, progress: 0.7))

        let library = try await libCtrl.loadLibrary()
        #expect(library.map(\.id) == BookRecord.samples.map(\.book.id) + [imported.id])
        #expect(library.first { $0.id == sampleID }?.progress == 0.7)
        #expect(library.first { $0.id == BookRecord.samples[1].book.id } == BookRecord.samples[1].book)
        #expect(library.last?.progress == 0)
        #expect(try libCtrl.libRepo.fetchBooks().first { $0.id == sampleID } == BookRecord.samples[0].book)
    }

    @Test("LIB-18 removing a book also drops its parsed content and cover from memory")
    func removeForgetsBook() async throws {
        let libCtrl = makeLibCtrl()
        let book = try await libCtrl.importBook(from: Fixture.url("epub3-cover"))
        _ = try await libCtrl.bookContentRepo.content(for: book.id)
        #expect(await libCtrl.cover(for: book.id) != nil)

        try await libCtrl.remove(book)
        #expect(await libCtrl.cover(for: book.id) == nil)
        await #expect(throws: ContentError.notFound) { try await libCtrl.bookContentRepo.content(for: book.id) }
    }
}
