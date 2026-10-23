import Foundation

actor BookContentRepo {
    private let epubParseSvc: EPUBParseSvc
    private var parsed: [UUID: BookContent] = [:]

    init(epubParseSvc: EPUBParseSvc) {
        self.epubParseSvc = epubParseSvc
    }

    func content(for bookID: UUID) async throws -> BookContent {
        if let content = parsed[bookID] { return content }

        let importedURL = URL.applicationSupportDirectory
            .appending(path: "Books/\(bookID.uuidString)/book.epub")
        let url: URL
        if FileManager.default.fileExists(atPath: importedURL.path) {
            url = importedURL
        } else if let bundledURL = Bundle.main.url(forResource: "little-women", withExtension: "epub") {
            url = bundledURL
        } else {
            throw ContentError.notFound
        }

        let content = try await epubParseSvc.parse(url)
        parsed[bookID] = content
        return content
    }
}
