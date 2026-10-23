import Foundation
import NaturalLanguage
import ZIPFoundation

struct EPUBParseSvcXML: EPUBParseSvc {
    func parse(_ url: URL) async throws -> BookContent {
        let archive = try Archive(url: url, accessMode: .read)
        let container = try elements(of: "META-INF/container.xml", in: archive)
        guard let opfPath = container.first(where: { $0.name == "rootfile" })?.attributes["full-path"] else {
            throw ContentError.unreadable
        }
        let opf = try elements(of: opfPath, in: archive)
        let folder = (opfPath as NSString).deletingLastPathComponent
        var paths: [String: String] = [:]
        for item in opf where item.name == "item" {
            if let id = item.attributes["id"], let href = item.attributes["href"] {
                paths[id] = path(of: href, in: folder)
            }
        }
        let spine = opf.filter { $0.name == "itemref" }.compactMap { $0.attributes["idref"].flatMap { paths[$0] } }
        let tocPath = opf.first { $0.name == "spine" }?.attributes["toc"].flatMap { paths[$0] }
        let tocEntries = try tocPath.map { try self.tocEntries(at: $0, in: archive) } ?? []
        let bookTitle = normalized(opf.first { $0.name == "dc:title" }?.text ?? "")

        var chapters: [RawChapter] = []
        for path in spine {
            let entries = tocEntries.filter { $0.path == path }
            let reader = try parseXML(data(path, in: archive), with: ChapterReader(anchorIDs: Set(entries.compactMap(\.fragment))))
            var titles: [Int: String] = [:]
            for (order, entry) in entries.enumerated() {
                // A file's first entry starts at its top, so text above its anchor stays in that chapter.
                if let index = order == 0 ? 0 : entry.fragment.flatMap({ reader.anchorParagraphs[$0] }) {
                    titles[index] = entry.title
                }
            }
            for (index, paragraph) in reader.paragraphs.enumerated() {
                if let title = titles[index] {
                    chapters.append(RawChapter(title: title))
                } else if chapters.isEmpty {
                    chapters.append(RawChapter(title: bookTitle))
                }
                chapters[chapters.count - 1].paragraphs.append(paragraph)
            }
        }
        guard !chapters.isEmpty else { throw ContentError.unreadable }
        return content(of: chapters)
    }

    private func content(of rawChapters: [RawChapter]) -> BookContent {
        let tokenizer = NLTokenizer(unit: .sentence)
        var chapters: [Chapter] = []
        var paragraphs: [Paragraph] = []
        var sentences: [Sentence] = []
        for (chapterIndex, rawChapter) in rawChapters.enumerated() {
            let firstParagraph = paragraphs.count
            var location = 0
            for text in rawChapter.paragraphs {
                let length = text.utf16.count
                sentences += sentenceRanges(in: text, tokenizer: tokenizer).map { Sentence(paragraph: paragraphs.count, range: $0) }
                paragraphs.append(Paragraph(
                    chapterIndex: chapterIndex,
                    range: NSRange(location: location, length: length),
                    wordCount: text.split(whereSeparator: \.isWhitespace).count
                ))
                location += length + 1
            }
            chapters.append(Chapter(
                title: rawChapter.title,
                text: rawChapter.paragraphs.joined(separator: "\n"),
                paragraphs: firstParagraph..<paragraphs.count
            ))
        }
        return BookContent(chapters: chapters, paragraphs: paragraphs, sentences: sentences, parserVersion: 1)
    }

    private func sentenceRanges(in text: String, tokenizer: NLTokenizer) -> [NSRange] {
        // Ebooks often put a no-break space after "Mr." or "Dr.", which the tokenizer reads as a sentence end.
        // A copy with plain spaces has the same UTF-16 length, so its ranges still match the original text.
        let plain = text.replacingOccurrences(of: "\u{00A0}", with: " ")
        tokenizer.string = plain
        return tokenizer.tokens(for: plain.startIndex..<plain.endIndex).compactMap { tokenRange in
            let range = NSRange(tokenRange, in: plain)
            let token = (text as NSString).substring(with: range)
            let sentence = token.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !sentence.isEmpty else { return nil }
            let leadingSpaces = token.prefix(while: \.isWhitespace).utf16.count
            return NSRange(location: range.location + leadingSpaces, length: sentence.utf16.count)
        }
    }

    private func tocEntries(at tocPath: String, in archive: Archive) throws -> [TocEntry] {
        let folder = (tocPath as NSString).deletingLastPathComponent
        var title = ""
        var entries: [TocEntry] = []
        for element in try elements(of: tocPath, in: archive) {
            if element.name == "text" {
                title = normalized(element.text)
            }
            if element.name == "content", let source = element.attributes["src"] {
                let parts = source.components(separatedBy: "#")
                entries.append(TocEntry(title: title, path: path(of: parts[0], in: folder), fragment: parts.dropFirst().first))
            }
        }
        return entries
    }

    private func elements(of path: String, in archive: Archive) throws -> [Element] {
        try parseXML(data(path, in: archive), with: ElementCollector()).elements
    }

    private func data(_ path: String, in archive: Archive) throws -> Data {
        guard let entry = archive[path] else { throw ContentError.unreadable }
        var data = Data()
        _ = try archive.extract(entry) { data.append($0) }
        return data
    }

    private func parseXML<Delegate: XMLParserDelegate>(_ data: Data, with delegate: Delegate) throws -> Delegate {
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse() else { throw ContentError.unreadable }
        return delegate
    }

    private func path(of href: String, in folder: String) -> String {
        (folder as NSString).appendingPathComponent(href.removingPercentEncoding ?? href)
    }

    private func normalized(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private struct RawChapter {
        let title: String
        var paragraphs: [String] = []
    }

    private struct TocEntry {
        let title: String
        let path: String
        let fragment: String?
    }

    private struct Element {
        let name: String
        let attributes: [String: String]
        var text = ""
    }

    private final class ElementCollector: NSObject, XMLParserDelegate {
        private(set) var elements: [Element] = []

        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                    qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
            elements.append(Element(name: elementName, attributes: attributeDict))
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            guard !elements.isEmpty else { return }
            elements[elements.count - 1].text += string
        }
    }

    private final class ChapterReader: NSObject, XMLParserDelegate {
        private(set) var paragraphs: [String] = []
        private(set) var anchorParagraphs: [String: Int] = [:]
        private let anchorIDs: Set<String>
        private var paragraph = ""
        private var isInBody = false

        private static let blocks: Set = [
            "p", "div", "section", "article", "header", "footer", "blockquote", "li", "tr", "br",
            "h1", "h2", "h3", "h4", "h5", "h6"
        ]

        init(anchorIDs: Set<String>) {
            self.anchorIDs = anchorIDs
        }

        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                    qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
            if elementName == "body" {
                isInBody = true
            }
            if Self.blocks.contains(elementName) {
                endParagraph()
            }
            if let id = attributeDict["id"], anchorIDs.contains(id) {
                endParagraph()
                anchorParagraphs[id] = paragraphs.count
            }
        }

        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
            if Self.blocks.contains(elementName) {
                endParagraph()
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            if isInBody {
                paragraph += string
            }
        }

        func parserDidEndDocument(_ parser: XMLParser) {
            endParagraph()
        }

        private func endParagraph() {
            let text = paragraph.replacing(/[ \t\r\n]+/, with: " ").trimmingCharacters(in: .whitespaces)
            if !text.isEmpty {
                paragraphs.append(text)
            }
            paragraph = ""
        }
    }
}
