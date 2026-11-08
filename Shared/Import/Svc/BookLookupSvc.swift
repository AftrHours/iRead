import Foundation

/// Looks up an Apple Books listing (iTunes Lookup API) and searches Project Gutenberg (its own OPDS search, about a second;
/// Gutendex was tried first and often took over 30 seconds). A protocol so tests stay offline.
protocol BookLookupSvc: Sendable {
    /// nil when Apple has no listing with this ID.
    func lookUpListing(id: String, country: String) async throws -> (title: String, author: String)?
    func searchGutenberg(for query: String) async throws -> [GutendexBook]
}

struct BookLookupSvcURLSession: BookLookupSvc {
    private struct Lookup: Decodable {
        struct Item: Decodable {
            let trackName: String?
            let artistName: String?
        }

        let results: [Item]
    }

    func lookUpListing(id: String, country: String) async throws -> (title: String, author: String)? {
        var components = URLComponents(string: "https://itunes.apple.com/lookup")!
        components.queryItems = [URLQueryItem(name: "id", value: id), URLQueryItem(name: "country", value: country)]
        return Self.decodeListing(try await fetch(components.url!))
    }

    func searchGutenberg(for query: String) async throws -> [GutendexBook] {
        var components = URLComponents(string: "https://www.gutenberg.org/ebooks/search.opds/")!
        components.queryItems = [URLQueryItem(name: "query", value: query)]
        return Self.decodeOPDS(try await fetch(components.url!))
    }

    static func decodeListing(_ data: Data) -> (title: String, author: String)? {
        guard let item = (try? JSONDecoder().decode(Lookup.self, from: data))?.results.first,
              let title = item.trackName else { return nil }
        return (title, item.artistName ?? "")
    }

    /// The books in a Gutenberg OPDS search feed. Each book entry's id ends in "/ebooks/<number>.opds"; entries that link to
    /// author or subject lists don't, and are skipped. Its content is the author ("Sigmund Freud"). The EPUB is at a fixed address.
    static func decodeOPDS(_ data: Data) -> [GutendexBook] {
        let reader = OPDSReader()
        let parser = XMLParser(data: data)
        parser.delegate = reader
        parser.parse()
        return reader.books
    }

    private func fetch(_ url: URL) async throws -> Data {
        guard let (data, response) = try? await URLSession.shared.data(for: URLRequest(url: url, timeoutInterval: 30)),
              (response as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) ?? false else {
            throw ImportError.unreachable
        }
        return data
    }
}

private final class OPDSReader: NSObject, XMLParserDelegate {
    private(set) var books: [GutendexBook] = []
    private var inEntry = false
    private var text = ""
    private var fields: [String: String] = [:]

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?,
                attributes: [String: String] = [:]) {
        if name == "entry" { inEntry = true; fields = [:] }
        text = ""
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        text += string
    }

    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
        guard inEntry else { return }
        if name == "entry" {
            inEntry = false
            guard let id = fields["id"], let number = GutenbergNumber.opdsEntry(id), let title = fields["title"] else { return }
            let author = fields["content"] ?? ""
            books.append(GutendexBook(
                id: number, title: title, authors: author.isEmpty ? [] : [.init(name: author)],
                formats: ["application/epub+zip": "https://www.gutenberg.org/ebooks/\(number).epub3.images"]
            ))
        } else {
            fields[name] = text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}
