import UIKit

struct PagerSvc {
    func pageRanges(for text: String, viewport: Viewport, settings: ReadingSettings) async -> [NSRange] {
        let pageSize = PageTextStyle.textFrame(in: CGRect(origin: .zero, size: viewport.size)).size
        let attributes = PageTextStyle.attributes(settings: settings, bodyFontSize: viewport.bodyFontSize)
        let storage = NSTextStorage(string: text, attributes: attributes)
        let layoutManager = NSLayoutManager()
        storage.addLayoutManager(layoutManager)
        var ranges: [NSRange] = []
        while NSMaxRange(ranges.last ?? NSRange()) < storage.length {
            let container = NSTextContainer(size: pageSize)
            container.lineFragmentPadding = 0
            layoutManager.addTextContainer(container)
            let glyphs = layoutManager.glyphRange(for: container)
            let range = layoutManager.characterRange(forGlyphRange: glyphs, actualGlyphRange: nil)
            guard range.length > 0 else { break }
            ranges.append(range)
        }
        return ranges.isEmpty ? [NSRange(location: 0, length: storage.length)] : ranges
    }
}
