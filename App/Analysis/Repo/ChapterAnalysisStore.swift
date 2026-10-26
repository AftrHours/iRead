import Foundation

struct ChapterAnalysisStore: Sendable {
    let root: URL

    func load(bookID: UUID, chapter: Int, engineVersion: Int, parserVersion: Int) -> ChapterAnalysis? {
        guard let data = try? Data(contentsOf: file(bookID: bookID, chapter: chapter)),
              let analysis = try? JSONDecoder().decode(ChapterAnalysis.self, from: data),
              analysis.engineVersion == engineVersion, analysis.parserVersion == parserVersion else { return nil }
        return analysis
    }

    func save(_ analysis: ChapterAnalysis, bookID: UUID) throws {
        try FileManager.default.createDirectory(at: folder(bookID: bookID), withIntermediateDirectories: true)
        try JSONEncoder().encode(analysis).write(to: file(bookID: bookID, chapter: analysis.chapter), options: .atomic)
    }

    func clear(bookID: UUID) throws {
        guard FileManager.default.fileExists(atPath: folder(bookID: bookID).path) else { return }
        try FileManager.default.removeItem(at: folder(bookID: bookID))
    }

    private func folder(bookID: UUID) -> URL {
        root.appending(path: "\(bookID.uuidString)/analysis")
    }

    private func file(bookID: UUID, chapter: Int) -> URL {
        folder(bookID: bookID).appending(path: "chapter-\(chapter).json")
    }
}
