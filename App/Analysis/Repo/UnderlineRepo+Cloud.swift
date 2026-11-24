import Foundation
import OSLog

/// Chapters kept in iCloud: asked for before the engine runs, and sent after it has.
extension UnderlineRepo {
    /// nil when iCloud has no current copy or can't be reached.
    func cloudChapter(_ chapter: Int, of book: String, parserVersion: Int) async -> StoredChapter? {
        guard let cloudSvc else { return nil }
        do {
            guard case .bytes(let data)? = try await cloudSvc.record(named: recordName(chapter, of: book), in: .reader)?["chapter"] else {
                noteCloud("Not in iCloud yet, so the engine ran", chapter: chapter, of: book)
                return nil
            }
            let stored = try JSONDecoder().decode(StoredChapter.self, from: data)
            guard isCurrent(stored, parserVersion: parserVersion) else {
                noteCloud("In iCloud from an older engine, so the engine ran", chapter: chapter, of: book)
                return nil
            }
            noteCloud("Loaded from iCloud", chapter: chapter, of: book)
            return stored
        } catch {
            logger.info("No underlines from iCloud for \(book, privacy: .public): \(error.localizedDescription, privacy: .public)")
            noteCloud("Couldn't ask iCloud: \(error.localizedDescription)", chapter: chapter, of: book)
            return nil
        }
    }

    func upload(_ stored: StoredChapter, chapter: Int, of book: String) async {
        guard let cloudSvc else { return }
        do {
            try await cloudSvc.save(["chapter": .bytes(JSONEncoder().encode(stored))], asRecord: recordName(chapter, of: book),
                                    ofType: Self.recordType, in: .reader)
            noteCloud("Underlined here and saved to iCloud", chapter: chapter, of: book)
        } catch {
            logger.info("Couldn't put underlines in iCloud for \(book, privacy: .public): \(error.localizedDescription, privacy: .public)")
            noteCloud("Underlined here, but couldn't save to iCloud: \(error.localizedDescription)", chapter: chapter, of: book)
        }
    }

    /// For the debug sheet only.
    func noteCloud(_ result: String, chapter: Int, of book: String) {
        #if DEBUG
        cloudResults[book, default: [:]][chapter] = result
        #endif
    }

    private func recordName(_ chapter: Int, of book: String) -> String {
        "\(book)-\(chapter)"
    }
}
