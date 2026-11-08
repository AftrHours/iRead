import Foundation
import UniformTypeIdentifiers

extension AppleBooksLink {
    /// The link in what another app shared. Every attachment is read in every type it offers (a URL, its bytes, plain or
    /// styled text), because apps differ and Apple Books' own attachments aren't documented. An Apple Books link wins;
    /// otherwise the first web link, so the sheet can say it isn't supported.
    @MainActor static func readLink(from providers: [NSItemProvider]) async -> URL? {
        let links = await loadEveryType(of: providers).flatMap(pullOutLinks(from:))
        return preferAppleBooksLink(links)
    }

    /// Each attachment in each type it offers.
    @MainActor private static func loadEveryType(of providers: [NSItemProvider]) async -> [Any] {
        var items: [Any] = []
        for provider in providers {
            for type in provider.registeredTypeIdentifiers {
                if let item = try? await provider.loadItem(forTypeIdentifier: type) { items.append(item) }
            }
        }
        return items
    }

    /// The first link `readListingID(from:)` can read, else the first web link, else any link.
    private static func preferAppleBooksLink(_ links: [URL]) -> URL? {
        links.first { readListingID(from: $0) != nil } ?? links.first { !$0.isFileURL } ?? links.first
    }

    private static func pullOutLinks(from item: Any) -> [URL] {
        switch item {
        case let url as URL: [url]
        case let text as String: pullOutLinks(fromText: text)
        case let styled as NSAttributedString: pullOutLinks(fromText: styled.string)
        case let data as Data:
            if let text = String(data: data, encoding: .utf8) {
                pullOutLinks(fromText: text)
            } else if let styled = try? NSAttributedString(data: data, options: [:], documentAttributes: nil) {
                pullOutLinks(fromText: styled.string)
            } else {
                []
            }
        default: []
        }
    }

    private static func pullOutLinks(fromText text: String) -> [URL] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmed), url.scheme != nil { return [url] }
        return firstURL(in: text).map { [$0] } ?? []
    }
}
