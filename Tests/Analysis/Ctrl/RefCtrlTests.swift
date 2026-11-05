import Foundation
import Testing
import UnderlineEngine
@testable import iRead

@Suite("RefCtrl", .timeLimit(.minutes(1)))
struct RefCtrlTests {
    private let folder = TempFolder()
    private let content = BookContent.make(chapters: [
        ["Then Anna saw the old clock in the hall.", "Later Anna wound the clock at noon.", "Soon Anna heard the clock strike one."],
        ["A new day began with rain.", "The rain stopped by evening."]
    ])

    private func makeRefCtrl() -> RefCtrl {
        let bookContentRepo = BookContentRepo(epubParseSvc: EPUBParseSvcSpy(content: content), folder: folder.url)
        return RefCtrl(bookID: sampleID, bookContentRepo: bookContentRepo, analysisRepo: .make(content: content, folder: folder.url),
                       underlineRepo: UnderlineRepo(folder: folder.url))
    }

    private func wholeChapter(_ index: Int) -> Page {
        let text = content.chapters[index].text
        return Page(number: index + 1, chapterIndex: index, range: NSRange(location: 0, length: text.utf16.count), text: text)
    }

    /// Stores the underlines as finished chapters and loads them, as showing a page of each chapter does.
    private func load(_ underlines: [Underline], into refCtrl: RefCtrl) async throws {
        for chapter in content.chapters.indices {
            let inChapter = underlines.filter { content.paragraphs[$0.paragraph].chapterIndex == chapter }
            try StoredUnderlines.write(inChapter, chapter: chapter, of: sampleID, parserVersion: content.parserVersion, in: folder.url)
            for await _ in try await refCtrl.underlineUpdates(from: wholeChapter(chapter)) {}
        }
    }

    private var clockInHall: Underline {
        .make("the clock", paragraph: 1, passage: "Then Anna saw the old clock in the hall.", passageParagraph: 0, in: content)
    }

    private var clockAtNoon: Underline {
        .make("the clock", paragraph: 2, passage: "Later Anna wound the clock at noon.", passageParagraph: 1, in: content)
    }

    private var rain: Underline {
        .make("The rain", paragraph: 4, passage: "A new day began with rain.", passageParagraph: 3, in: content)
    }

    @Test("AN-06 only underlines in the page's chapter become marks, relative to the page")
    func underlineMarks() async throws {
        let refCtrl = makeRefCtrl()
        try await load([clockInHall, rain], into: refCtrl)
        let start = 5
        let page = Page(number: 1, chapterIndex: 0, range: NSRange(location: start, length: content.chapters[0].text.utf16.count - start), text: "")

        let marks = try await refCtrl.marks(on: page, highlighting: nil, includingSymbols: false, editedSymbols: [:])
        let location = content.paragraphs[1].range.location + clockInHall.range.location - start
        #expect(marks == [Mark(range: NSRange(location: location, length: clockInHall.range.length), kind: .underline(id: clockInHall.id))])
    }

    @Test("AN-07 highlighting an underline marks only its reference passage")
    func highlight() async throws {
        let refCtrl = makeRefCtrl()
        try await load([clockInHall, clockAtNoon], into: refCtrl)
        let marks = try await refCtrl.marks(on: wholeChapter(0), highlighting: clockAtNoon.id, includingSymbols: false, editedSymbols: [:])
        let reference = clockAtNoon.reference
        let expected = NSRange(location: content.paragraphs[reference.paragraph].range.location + reference.range.location, length: reference.range.length)
        #expect(marks.filter { $0.kind == .highlight } == [Mark(range: expected, kind: .highlight)])
    }

    @Test("AN-08 symbols are left out unless asked for")
    func noSymbols() async throws {
        let refCtrl = makeRefCtrl()
        await refCtrl.startAnalysis()
        for await _ in await refCtrl.analysisUpdates() {}
        func symbolCount(_ including: Bool) async throws -> Int {
            try await refCtrl.marks(on: wholeChapter(0), highlighting: nil, includingSymbols: including, editedSymbols: [:])
                .count { if case .symbol = $0.kind { true } else { false } }
        }
        #expect(try await symbolCount(true) > 0)
        #expect(try await symbolCount(false) == 0)
    }

    @Test("AN-09 an unknown underline isn't found")
    func unknownUnderline() async {
        await #expect(throws: ContentError.notFound) { try await makeRefCtrl().underline(withID: "99:0") }
    }

    @Test("AN-10 a symbol card for a mention out of range isn't found")
    func unknownMention() async {
        await #expect(throws: ContentError.notFound) { try await makeRefCtrl().symbolCard(forMention: 99) }
    }

    @Test("AN-11 a chapter's characters are listed in the order they first appear")
    func entitiesInOrder() async throws {
        let content = BookContent.make(chapters: [["Then Bella came in.", "Then Anna sat down.", "Then Bella left.", "Later Anna smiled."]])
        let analysisRepo = AnalysisRepo.make(content: content, folder: folder.url)
        let refCtrl = RefCtrl(bookID: sampleID, bookContentRepo: BookContentRepo(epubParseSvc: EPUBParseSvcSpy(content: content), folder: folder.url),
                              analysisRepo: analysisRepo, underlineRepo: UnderlineRepo(folder: folder.url))
        _ = await analysisRepo.runToEnd(sampleID)
        #expect(try await refCtrl.entities(inChapter: 0).map(\.name) == ["Bella", "Anna"])
    }
}
