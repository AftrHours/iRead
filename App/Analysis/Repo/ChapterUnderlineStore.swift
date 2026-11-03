import Foundation
import UnderlineEngine

struct StoredUnderlines: Codable, Sendable {
    let chapter: Int
    let engineVersion: Int
    let parserVersion: Int
    let usedModel: Bool
    let underlines: [Underline]
    let dropped: [DroppedPhrase]
}

struct ChapterUnderlineStore: Sendable {
    let root: URL

    func load(bookID: UUID, chapter: Int, engineVersion: Int, parserVersion: Int, usesModel: Bool) -> StoredUnderlines? {
        guard let data = try? Data(contentsOf: file(bookID: bookID, chapter: chapter)),
              let stored = try? JSONDecoder().decode(StoredUnderlines.self, from: data),
              stored.engineVersion == engineVersion, stored.parserVersion == parserVersion, stored.usedModel == usesModel else { return nil }
        return stored
    }

    func save(_ stored: StoredUnderlines, bookID: UUID) throws {
        try FileManager.default.createDirectory(at: folder(bookID: bookID), withIntermediateDirectories: true)
        try JSONEncoder().encode(stored).write(to: file(bookID: bookID, chapter: stored.chapter), options: .atomic)
    }

    private func folder(bookID: UUID) -> URL {
        root.appending(path: "\(bookID.uuidString)/underlines")
    }

    private func file(bookID: UUID, chapter: Int) -> URL {
        folder(bookID: bookID).appending(path: "chapter-\(chapter).json")
    }
}
