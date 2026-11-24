import Foundation
import Testing
@testable import iRead

@Suite("CharacterCtrl")
struct CharacterCtrlTests {
    private let folder = TempFolder()

    /// The characters met before the chapter whose text contains `chapterText`, by name, with their passage.
    private func characters(in title: String, before chapterText: String) async throws -> [String: String?] {
        let sample = try #require(BookRecord.samples.first { $0.book.title == title }).book
        let bookContentRepo = BookContentRepo(epubParseSvc: EPUBParseSvcEPUBKit(), folder: folder.url)
        let content = try await bookContentRepo.content(for: sample.id)
        let chapter = try #require(content.chapters.firstIndex { $0.text.contains(chapterText) })
        let page = Page(number: 1, chapterIndex: chapter, range: NSRange(location: 0, length: 0), text: "")
        let characters = try await CharacterCtrl(bookID: sample.id, bookContentRepo: bookContentRepo).characters(through: page)
        return Dictionary(characters.map { ($0.name, $0.passage?.text) }, uniquingKeysWith: { first, _ in first })
    }

    @Test("CH-07 Little Women, chapters 1–4: each sister's introduction, Laurie's unnamed description, none for Mr. Laurence",
          .tags(.golden))
    func littleWomen() async throws {
        let found = try await characters(in: "Little Women", before: "What in the world are you going to do now, Jo?")
        #expect(found["Meg/Margaret"]??.hasPrefix("Margaret, the eldest of the four, was six") == true)
        #expect(found["Jo/Josephine"]??.hasPrefix("Fifteen-year-old Jo was very tall, thin,") == true)
        #expect(found["Beth/Bethy"]??.hasPrefix("Elizabeth, or Beth, as everyone called he") == true)
        #expect(found["Amy"]??.hasPrefix("Amy, though the youngest, was a most imp") == true)
        #expect(found["Laurie/Theodore"]??.hasPrefix("“Curly black hair, brown skin, big black") == true)
        #expect(found["Mr. Laurence"] == .some(nil))
    }

    @Test("CH-08 Pride and Prejudice, to chapter 16: descriptions of Bingley, Darcy, Lydia and Mr. Bennet", .tags(.golden))
    func prideAndPrejudice() async throws {
        let found = try await characters(in: "Pride and Prejudice", before: "In describing to her all the grandeur")
        #expect(found["Mr. Bingley"]??.hasPrefix("Mr. Bingley was good-looking and gentlem") == true)
        #expect(found["Mr. Darcy"]??.contains("Mr. Hurst") == true)
        #expect(found["Lydia"]??.hasPrefix("Lydia was a stout, well-grown girl of fi") == true)
        #expect(found["Mr. Bennet"]??.hasPrefix("Mr. Bennet was so odd a mixture of quick") == true)
    }
}
