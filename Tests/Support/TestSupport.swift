import Foundation
import Testing
@testable import iRead

extension Tag {
    /// Slow checks against stored snapshots of real books. Only the Full test plan runs them.
    @Tag static var golden: Self
}

/// A fresh folder for one test. Swift Testing makes a new suite value for every test, so a suite that holds one
/// gives each test its own folder, deleted when the test ends.
final class TempFolder: Sendable {
    let url = URL.temporaryDirectory.appending(path: "iReadTests-\(UUID().uuidString)", directoryHint: .isDirectory)

    init() {
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: url)
    }
}

/// The EPUB files in Tests/Fixtures, built by make-fixtures.sh.
enum Fixture {
    private final class BundleToken {}

    static func url(_ name: String) throws -> URL {
        try #require(Bundle(for: BundleToken.self).url(forResource: name, withExtension: "epub"), "Missing fixture \(name).epub")
    }

    /// Copies a fixture to where LibRepo keeps an imported book: `<folder>/<id>/book.epub`.
    static func importedBook(_ name: String, into folder: URL, id: UUID = UUID()) throws -> UUID {
        let destination = folder.appending(path: "\(id.uuidString)/book.epub")
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: url(name), to: destination)
        return id
    }
}

extension BookContent {
    /// Content built by the same code EPUBParseSvc uses, so paragraph and sentence ranges match a parsed book.
    /// One array of paragraphs per chapter.
    static func make(chapters: [[String]], titles: [String]? = nil) -> BookContent {
        EPUBParseSvcEPUBKit.content(of: chapters.enumerated().map { index, paragraphs in
            (titles?[index] ?? "Chapter \(index + 1)", paragraphs)
        })
    }

    /// The text of one paragraph, as the reader shows it.
    func text(ofParagraph index: Int) -> String {
        (chapters[paragraphs[index].chapterIndex].text as NSString).substring(with: paragraphs[index].range)
    }

    func text(ofSentence index: Int) -> String {
        let sentence = sentences[index]
        let paragraph = paragraphs[sentence.paragraph]
        let range = NSRange(location: paragraph.range.location + sentence.range.location, length: sentence.range.length)
        return (chapters[paragraph.chapterIndex].text as NSString).substring(with: range)
    }
}

extension ReadingProgress {
    static func make(bookID: UUID = UUID(), paragraph: Int = 0, charOffset: Int = 0, chapterIndex: Int = 0, progress: Double = 0,
                     lastReadAt: Date = Date(timeIntervalSince1970: 1_700_000_000), readingFrontier: Int = 0,
                     finishedAt: Date? = nil) -> ReadingProgress {
        ReadingProgress(bookID: bookID, position: ReadingPosition(paragraph: paragraph, charOffset: charOffset), chapterIndex: chapterIndex,
                        progress: progress, lastReadAt: lastReadAt, readingFrontier: readingFrontier, finishedAt: finishedAt)
    }
}

/// A sample book's ID. Its bundled EPUB exists, so BookContentRepo finds a file for it; a fake parser decides the content.
let sampleID = BookRecord.samples[0].book.id

/// Waits until `condition` is true, checking every few milliseconds, for at most `seconds`.
func eventually(within seconds: Double = 5, isolation: isolated (any Actor)? = #isolation, _ condition: () async -> Bool) async -> Bool {
    let deadline = Date.now.addingTimeInterval(seconds)
    while Date.now < deadline {
        if await condition() { return true }
        try? await Task.sleep(for: .milliseconds(10))
    }
    return await condition()
}

/// An iPad-sized page, for ReaderCtrl and PagerSvc.
let iPadViewport = Viewport(size: CGSize(width: 820, height: 1180))

/// UnderlineRepo's file for one finished chapter: `<folder>/<book fingerprint>/chapter-N.json`.
enum StoredUnderlines {
    struct File: Codable {
        let parserVersion: Int
        let engineVersion: Int?
        let underlines: [SavedUnderline]
    }

    static func url(chapter: Int, of book: String, in folder: URL) -> URL {
        folder.appending(path: "\(book)/chapter-\(chapter).json")
    }

    /// `engineVersion: nil` writes a file without the field, like builds before it existed.
    static func write(_ underlines: [SavedUnderline], chapter: Int, of book: String, parserVersion: Int,
                      engineVersion: Int? = UnderlineRepoKnobs.engineVersion, in folder: URL) throws {
        let url = url(chapter: chapter, of: book, in: folder)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(File(parserVersion: parserVersion, engineVersion: engineVersion, underlines: underlines)).write(to: url)
    }

    static func read(chapter: Int, of book: String, in folder: URL) throws -> File {
        try JSONDecoder().decode(File.self, from: Data(contentsOf: url(chapter: chapter, of: book, in: folder)))
    }
}

extension SavedUnderline {
    /// An underline on `phrase` in one paragraph, explained by `passage` in another.
    static func make(_ phrase: String, paragraph: Int, passage: String, passageParagraph: Int, in content: BookContent) -> SavedUnderline {
        let range = (content.text(ofParagraph: paragraph) as NSString).range(of: phrase)
        let passageRange = (content.text(ofParagraph: passageParagraph) as NSString).range(of: passage)
        func sentence(_ paragraph: Int, _ range: NSRange) -> Int {
            content.sentences.firstIndex { $0.paragraph == paragraph && NSLocationInRange(range.location, $0.range) } ?? 0
        }
        let underlined = sentence(paragraph, range)
        return SavedUnderline(id: "\(underlined):\(range.location)", sentence: underlined, paragraph: paragraph, range: range, text: phrase,
                              kind: "thing", decidedBy: "rules",
                              reference: ContextPassage(sentence: sentence(passageParagraph, passageRange), paragraph: passageParagraph,
                                                        range: passageRange, text: passage))
    }
}
