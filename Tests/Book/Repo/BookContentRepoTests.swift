import Foundation
import Testing
@testable import iRead

@Suite("BookContentRepo")
struct BookContentRepoTests {
    private let folder = TempFolder()

    @Test("BK-08 two callers at once share one parse")
    func concurrentCallsParseOnce() async throws {
        let spy = EPUBParseSvcSpy()
        let repo = BookContentRepo(epubParseSvc: spy, folder: folder.url)
        let bookID = try Fixture.importedBook("minimal", into: folder.url)

        async let first = repo.content(for: bookID)
        async let second = repo.content(for: bookID)
        let (a, b) = try await (first, second)

        #expect(spy.parseCount == 1)
        #expect(a.chapters.map(\.text) == b.chapters.map(\.text))
        #expect(a.chapters.count == 2)
    }

    @Test("BK-09 a failed parse isn't cached, so a retry parses again")
    func failureNotCached() async throws {
        let spy = EPUBParseSvcSpy(failures: 1)
        let repo = BookContentRepo(epubParseSvc: spy, folder: folder.url)
        let bookID = try Fixture.importedBook("minimal", into: folder.url)

        await #expect(throws: ContentError.unreadable) { try await repo.content(for: bookID) }
        let content = try await repo.content(for: bookID)
        #expect(content.chapters.count == 2)
        #expect(spy.parseCount == 2)
    }

    @Test("BK-10 an unknown book isn't found")
    func unknownBook() async {
        let repo = BookContentRepo(epubParseSvc: EPUBParseSvcSpy(), folder: folder.url)
        await #expect(throws: ContentError.notFound) { try await repo.content(for: UUID()) }
    }

    @Test("BK-11 an imported book.epub wins over the bundled sample with the same ID")
    func importedWinsOverSample() async throws {
        let repo = BookContentRepo(epubParseSvc: EPUBParseSvcEPUBKit(), folder: folder.url)
        _ = try Fixture.importedBook("minimal", into: folder.url, id: sampleID)
        let content = try await repo.content(for: sampleID)
        #expect(content.chapters.map(\.title) == ["Chapter One", "Chapter Two"])
    }

    @Test("BK-12 the shared copy is named after the title, with / and : replaced")
    func shareableFile() async throws {
        let repo = BookContentRepo(epubParseSvc: EPUBParseSvcEPUBKit(), folder: folder.url)
        let bookID = try Fixture.importedBook("minimal", into: folder.url)
        let book = BookRecord(id: bookID, title: "Good/Bad: A Tale", author: "Someone", isContinueReading: false, progress: 0)

        let url = try await repo.shareableFile(for: book)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        #expect(url.lastPathComponent == "Good-Bad- A Tale.epub")
        #expect(try Data(contentsOf: url) == Data(contentsOf: Fixture.url("minimal")))
    }

    @Test("BK-14 only the 2 most recently used books stay parsed; a 3rd evicts the oldest")
    func keepsTwoRecentBooks() async throws {
        let spy = EPUBParseSvcSpy()
        let repo = BookContentRepo(epubParseSvc: spy, folder: folder.url)
        let (first, second, third) = try (Fixture.importedBook("minimal", into: folder.url), Fixture.importedBook("minimal", into: folder.url),
                                          Fixture.importedBook("minimal", into: folder.url))

        for bookID in [first, second, third] {
            _ = try await repo.content(for: bookID)
        }
        _ = try await repo.content(for: second)
        _ = try await repo.content(for: third)
        #expect(spy.parseCount == 3)

        // The first book was evicted, and two callers reopening it at once still share one parse.
        async let again = repo.content(for: first)
        async let againToo = repo.content(for: first)
        _ = try await (again, againToo)
        #expect(spy.parseCount == 4)
        // Reopening the first book evicted the second, the least recently used.
        _ = try await repo.content(for: third)
        #expect(spy.parseCount == 4)
        _ = try await repo.content(for: second)
        #expect(spy.parseCount == 5)
    }

    @Test("BK-15 a forgotten book is parsed again, and its cover is read again")
    func forget() async throws {
        let spy = EPUBParseSvcSpy()
        let repo = BookContentRepo(epubParseSvc: spy, folder: folder.url)
        let bookID = try Fixture.importedBook("epub3-cover", into: folder.url)
        _ = try await repo.content(for: bookID)
        #expect(await repo.cover(for: bookID) != nil)

        await repo.forget(bookID)
        _ = try await repo.content(for: bookID)
        #expect(spy.parseCount == 2)
        // With the file gone, only a cached cover could still be returned.
        try FileManager.default.removeItem(at: folder.url.appending(path: bookID.uuidString))
        await repo.forget(bookID)
        #expect(await repo.cover(for: bookID) == nil)
        await #expect(throws: ContentError.notFound) { try await repo.content(for: bookID) }
    }
}
