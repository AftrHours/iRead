import Foundation
import Testing
@testable import iRead

@Suite("RefCtrl", .timeLimit(.minutes(1)))
struct RefCtrlTests {
    private let folder = TempFolder()
    private let content = BookContent.make(chapters: [
        ["Then Anna saw the old clock in the hall.", "Later Anna wound the clock at noon.", "Soon Anna heard the clock strike one."],
        ["A new day began with rain.", "The rain stopped by evening."]
    ])

    private func makeRefCtrl() -> RefCtrl {
        RefCtrl(bookID: sampleID, bookContentRepo: BookContentRepo(epubParseSvc: EPUBParseSvcSpy(content: content), folder: folder.url),
                underlineRepo: UnderlineRepo(folder: folder.url))
    }

    private func wholeChapter(_ index: Int) -> Page {
        let text = content.chapters[index].text
        return Page(number: index + 1, chapterIndex: index, range: NSRange(location: 0, length: text.utf16.count), text: text)
    }

    /// Stores the underlines as finished chapters and loads them, as showing a page of each chapter does.
    private func load(_ underlines: [SavedUnderline], into refCtrl: RefCtrl) async throws {
        for chapter in content.chapters.indices {
            let inChapter = underlines.filter { content.paragraphs[$0.paragraph].chapterIndex == chapter }
            try StoredUnderlines.write(inChapter, chapter: chapter, of: content.fingerprint, parserVersion: content.parserVersion, in: folder.url)
            for await _ in try await refCtrl.underlineUpdates(from: wholeChapter(chapter)) {}
        }
    }

    private var clockInHall: SavedUnderline {
        .make("the clock", paragraph: 1, passage: "Then Anna saw the old clock in the hall.", passageParagraph: 0, in: content)
    }

    private var clockAtNoon: SavedUnderline {
        .make("the clock", paragraph: 2, passage: "Later Anna wound the clock at noon.", passageParagraph: 1, in: content)
    }

    private var rain: SavedUnderline {
        .make("The rain", paragraph: 4, passage: "A new day began with rain.", passageParagraph: 3, in: content)
    }

    @Test("AN-06 only underlines in the page's chapter become marks, relative to the page")
    func underlineMarks() async throws {
        let refCtrl = makeRefCtrl()
        try await load([clockInHall, rain], into: refCtrl)
        let start = 5
        let page = Page(number: 1, chapterIndex: 0, range: NSRange(location: start, length: content.chapters[0].text.utf16.count - start), text: "")

        let marks = try await refCtrl.marks(on: page, highlighting: nil)
        let location = content.paragraphs[1].range.location + clockInHall.range.location - start
        #expect(marks == [Mark(range: NSRange(location: location, length: clockInHall.range.length), kind: .underline(id: clockInHall.id))])
    }

    @Test("AN-07 highlighting an underline marks only its reference passage")
    func highlight() async throws {
        let refCtrl = makeRefCtrl()
        try await load([clockInHall, clockAtNoon], into: refCtrl)
        let marks = try await refCtrl.marks(on: wholeChapter(0), highlighting: clockAtNoon.id)
        let reference = clockAtNoon.reference
        let expected = NSRange(location: content.paragraphs[reference.paragraph].range.location + reference.range.location, length: reference.range.length)
        #expect(marks.filter { $0.kind == .highlight } == [Mark(range: expected, kind: .highlight)])
    }

    @Test("AN-28 highlighting an underline whose passage is in an earlier chapter marks the passage on that chapter's page")
    func highlightInEarlierChapter() async throws {
        let refCtrl = makeRefCtrl()
        let rainAfterClock = SavedUnderline.make("The rain", paragraph: 4, passage: "Then Anna saw the old clock in the hall.",
                                                 passageParagraph: 0, in: content)
        try await load([rainAfterClock], into: refCtrl)
        let marks = try await refCtrl.marks(on: wholeChapter(0), highlighting: rainAfterClock.id)
        let reference = rainAfterClock.reference
        let expected = NSRange(location: content.paragraphs[reference.paragraph].range.location + reference.range.location, length: reference.range.length)
        #expect(marks == [Mark(range: expected, kind: .highlight)])
    }

    @Test("AN-09 an unknown underline isn't found")
    func unknownUnderline() async {
        await #expect(throws: ContentError.notFound) { try await makeRefCtrl().underline(withID: "99:0") }
    }
}
