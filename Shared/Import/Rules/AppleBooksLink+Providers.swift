import Foundation
import UniformTypeIdentifiers

extension AppleBooksLink {
    /// The link in what another app shared. Every attachment is read in every type it offers (a URL, its bytes, plain or
    /// styled text), because apps differ and Apple Books' own attachments aren't documented. An Apple Books link wins;
    /// otherwise the first web link, so the sheet can say it isn't supported.
    @MainActor static func find(in providers: [NSItemProvider]) async -> URL? {
        var links: [URL] = []
        for provider in providers {
            for type in provider.registeredTypeIdentifiers {
                guard let item = try? await provider.loadItem(forTypeIdentifier: type) else { continue }
                links += Self.links(in: item)
            }
        }
        return links.first { listing(in: $0) != nil } ?? links.first { !$0.isFileURL } ?? links.first
    }

    private static func links(in item: Any) -> [URL] {
        switch item {
        case let url as URL: [url]
        case let text as String: links(inText: text)
        case let styled as NSAttributedString: links(inText: styled.string)
        case let data as Data:
            if let text = String(data: data, encoding: .utf8) {
                links(inText: text)
            } else if let styled = try? NSAttributedString(data: data, options: [:], documentAttributes: nil) {
                links(inText: styled.string)
            } else {
                []
            }
        default: []
        }
    }

    private static func links(inText text: String) -> [URL] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmed), url.scheme != nil { return [url] }
        return firstURL(in: text).map { [$0] } ?? []
    }
}
