import Foundation

enum AppleBooksLink {
    /// The listing ID (from an `id<digits>` path segment or an `id` query item) and the store country (a two-letter
    /// first path segment, else "us"). nil for a link that isn't on apple.com or has no ID.
    static func readListingID(from url: URL) -> (id: String, country: String)? {
        guard let host = url.host?.lowercased(), host == "apple.com" || host.hasSuffix(".apple.com") else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }
        // The digits right after "id": Apple Books' Share Book adds a letter after them (".../id395687522P").
        let pathID = parts.lazy
            .filter { $0.hasPrefix("id") }
            .map { String($0.dropFirst(2).prefix { $0.isASCII && $0.isNumber }) }
            .first { !$0.isEmpty }
        let queryID = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "id" }?.value
        guard let id = pathID ?? queryID, !id.isEmpty else { return nil }
        let country = parts.first.flatMap { $0.count == 2 ? $0.lowercased() : nil } ?? "us"
        return (id, country)
    }

    /// The first link in shared text: Apple Books sometimes shares "Check out <title> … <link>".
    static func firstURL(in text: String) -> URL? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        return detector?.firstMatch(in: text, range: NSRange(text.startIndex..., in: text))?.url
    }
}
