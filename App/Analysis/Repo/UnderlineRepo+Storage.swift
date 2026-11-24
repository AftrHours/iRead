import Foundation
import OSLog

/// Chapters saved on this device and the ones bundled with the app.
extension UnderlineRepo {
    /// A chapter is finished when this device saved it, or when the app comes with it: the bundled books are worked out
    /// ahead, so a reader never waits on the engine for them. Either way iCloud isn't asked.
    func isFinished(_ chapter: Int, of book: String, parserVersion: Int) -> Bool {
        if finishedChapters[book]?.contains(chapter) == true { return true }
        if let stored = storedChapter(at: fileURL(chapter: chapter, of: book, in: folder), parserVersion: parserVersion) {
            use(stored, chapter: chapter, of: book)
            noteCloud("Saved on this device, so iCloud wasn't asked", chapter: chapter, of: book)
            return true
        }
        if let seedFolder,
           let stored = storedChapter(at: fileURL(chapter: chapter, of: book, in: seedFolder), parserVersion: parserVersion) {
            use(stored, chapter: chapter, of: book)
            noteCloud("Comes with the app, so iCloud wasn't asked", chapter: chapter, of: book)
            return true
        }
        return false
    }

    /// nil when there's no file, or it was made by another parser or engine version.
    func storedChapter(at url: URL, parserVersion: Int) -> StoredChapter? {
        guard let data = try? Data(contentsOf: url),
              let stored = try? JSONDecoder().decode(StoredChapter.self, from: data),
              isCurrent(stored, parserVersion: parserVersion) else { return nil }
        return stored
    }

    func isCurrent(_ stored: StoredChapter, parserVersion: Int) -> Bool {
        stored.parserVersion == parserVersion && stored.engineVersion == UnderlineRepoKnobs.engineVersion
    }

    func use(_ stored: StoredChapter, chapter: Int, of book: String) {
        foundUnderlines[book, default: [:]][chapter] = stored.underlines
        finishedChapters[book, default: []].insert(chapter)
    }

    func save(_ stored: StoredChapter, chapter: Int, of book: String) {
        let url = fileURL(chapter: chapter, of: book)
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(stored).write(to: url, options: .atomic)
        } catch {
            logger.error("Couldn't save underlines for \(book, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    private func fileURL(chapter: Int, of book: String, in folder: URL? = nil) -> URL {
        (folder ?? self.folder).appending(path: "\(book)/chapter-\(chapter).json")
    }
}
