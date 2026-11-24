import Foundation
import Testing
@testable import iRead

@Suite("PagerSvc")
struct PagerSvcTests {
    private let pager = PagerSvcTextKit()
    private let longText = (1...400).map { "Sentence number \($0) is here to fill the page with some words." }.joined(separator: " ")

    @Test("RD-10 pages cover long text from start to end with no gaps, overlaps or empty pages")
    func contiguous() async {
        let ranges = await pager.pageRanges(for: longText, viewport: iPadViewport, settings: ReadingSettings())
        #expect(ranges.count > 1)
        #expect(ranges.first?.location == 0)
        #expect(ranges.allSatisfy { $0.length > 0 })
        for (previous, next) in zip(ranges, ranges.dropFirst()) {
            #expect(NSMaxRange(previous) == next.location)
        }
        #expect(ranges.last.map(NSMaxRange) == longText.utf16.count)
    }

    @Test("RD-11 empty text is one empty page")
    func emptyText() async {
        #expect(await pager.pageRanges(for: "", viewport: iPadViewport, settings: ReadingSettings()) == [NSRange(location: 0, length: 0)])
    }

    @Test("RD-12 bigger text makes more pages")
    func textSize() async {
        var small = ReadingSettings()
        small.textSizeIndex = 3
        var large = ReadingSettings()
        large.textSizeIndex = 8
        let smallPages = await pager.pageRanges(for: longText, viewport: iPadViewport, settings: small)
        let largePages = await pager.pageRanges(for: longText, viewport: iPadViewport, settings: large)
        #expect(largePages.count > smallPages.count)
    }
}
