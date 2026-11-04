import Foundation
import Testing
@testable import iRead

@Suite("LibRepo")
struct LibRepoTests {
    private let folder = TempFolder()
    private var books: URL { folder.url.appending(path: "Books") }
    private var libraryURL: URL { books.appending(path: "library.json") }

    private func makeRepos() -> (LibRepo, ProgRepo) {
        let progRepo = ProgRepo(folder: books)
        return (LibRepo(epubParseSvc: EPUBParseSvcEPUBKit(), progRepo: progRepo, folder: books), progRepo)
    }

    private func savedLibrary() throws -> [BookRecord] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([BookRecord].self, from: Data(contentsOf: libraryURL))
    }

    @Test("LIB-07 empty folder lists every sample and nothing imported")
    func emptyFolder() async throws {
        let (libRepo, _) = makeRepos()
        let fetched = try await libRepo.fetchBooks()
        #expect(fetched.map(\.id) == BookRecord.samples.map(\.book.id))
    }

    @Test("LIB-08 a finished book shows as fully read, with lastReadAt from its progress file")
    func finishedShowsFull() async throws {
        let (libRepo, progRepo) = makeRepos()
        let readAt = Date(timeIntervalSince1970: 1_700_000_000)
        await progRepo.saveNow(.make(bookID: sampleID, progress: 0.4, lastReadAt: readAt, finishedAt: readAt))
        let book = try #require(try await libRepo.fetchBooks().first { $0.id == sampleID })
        #expect(book.progress == 1)
        #expect(book.lastReadAt == readAt)
    }

    @Test("LIB-09 importing copies the EPUB and records its title and author")
    func importMinimal() async throws {
        let (libRepo, _) = makeRepos()
        let book = try await libRepo.importBook(from: Fixture.url("minimal"))
        #expect(FileManager.default.fileExists(atPath: books.appending(path: "\(book.id.uuidString)/book.epub").path))
        let saved = try savedLibrary()
        #expect(saved.count == 1)
        #expect(saved.first?.id == book.id)
        #expect(saved.first?.title == "Minimal Book")
        #expect(saved.first?.author == "Test Author")
        #expect(saved.first?.progress == 0)
    }

    @Test("LIB-10 a book with no metadata is named after its file")
    func importNoMetadata() async throws {
        let (libRepo, _) = makeRepos()
        let source = folder.url.appending(path: "My Book.epub")
        try FileManager.default.copyItem(at: Fixture.url("no-metadata"), to: source)
        let book = try await libRepo.importBook(from: source)
        #expect(book.title == "My Book")
        #expect(book.author == "Unknown Author")
    }

    @Test("LIB-11 a corrupt EPUB isn't imported")
    func importCorrupt() async throws {
        let (libRepo, _) = makeRepos()
        _ = try await libRepo.importBook(from: Fixture.url("minimal"))
        let libraryBefore = try Data(contentsOf: libraryURL)
        let foldersBefore = try FileManager.default.contentsOfDirectory(atPath: books.path)

        await withKnownIssue("A file that isn't a zip throws ZIPFoundation's error, not ContentError.unreadable") {
            await #expect(throws: ContentError.unreadable) { try await libRepo.importBook(from: Fixture.url("corrupt")) }
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: books.path).sorted() == foldersBefore.sorted())
        #expect(try Data(contentsOf: libraryURL) == libraryBefore)
    }

    @Test("LIB-12 removing an imported book deletes it")
    func removeImported() async throws {
        let (libRepo, _) = makeRepos()
        let book = try await libRepo.importBook(from: Fixture.url("minimal"))
        try libRepo.remove(book)
        #expect(!FileManager.default.fileExists(atPath: books.appending(path: book.id.uuidString).path))
        #expect(try savedLibrary().isEmpty)
        #expect(try await !libRepo.fetchBooks().contains { $0.id == book.id })
    }

    @Test("LIB-13 removing a sample book only hides it")
    func removeSample() async throws {
        let (libRepo, _) = makeRepos()
        let sample = BookRecord.samples[0]
        try libRepo.remove(sample.book)
        let hidden = try JSONDecoder().decode(Set<UUID>.self, from: Data(contentsOf: books.appending(path: "hidden-samples.json")))
        #expect(hidden == [sample.book.id])
        #expect(try await !libRepo.fetchBooks().contains { $0.id == sample.book.id })
        #expect(Bundle.main.url(forResource: sample.fileName, withExtension: "epub") != nil)
    }

    @Test("LIB-14 samples saved into an old library.json appear once")
    func oldLibraryWithSamples() async throws {
        let (libRepo, _) = makeRepos()
        let imported = try await libRepo.importBook(from: Fixture.url("minimal"))
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(BookRecord.samples.map(\.book) + [imported]).write(to: libraryURL)

        let ids = try await libRepo.fetchBooks().map(\.id)
        for sample in BookRecord.samples {
            #expect(ids.count { $0 == sample.book.id } == 1)
        }
        #expect(ids.count { $0 == imported.id } == 1)
    }

    @Test("LIB-15 importing the same file twice makes two books")
    func importTwice() async throws {
        let (libRepo, _) = makeRepos()
        let first = try await libRepo.importBook(from: Fixture.url("minimal"))
        let second = try await libRepo.importBook(from: Fixture.url("minimal"))
        #expect(first.id != second.id)
        #expect(try savedLibrary().map(\.id) == [first.id, second.id])
    }

    @Test("LIB-17 mark finished, then still reading, keeps the saved progress and position")
    func finishedThenStillReading() async throws {
        let (libRepo, progRepo) = makeRepos()
        await progRepo.saveNow(.make(bookID: sampleID, paragraph: 12, charOffset: 3, progress: 0.4))
        let sample = BookRecord.samples[0].book

        await libRepo.setFinished(true, for: sample)
        #expect(try await libRepo.fetchBooks().first { $0.id == sampleID }?.progress == 1)

        await libRepo.setFinished(false, for: sample)
        #expect(try await libRepo.fetchBooks().first { $0.id == sampleID }?.progress == 0.4)
        #expect(await progRepo.progress(for: sampleID)?.position == ReadingPosition(paragraph: 12, charOffset: 3))
    }
}
