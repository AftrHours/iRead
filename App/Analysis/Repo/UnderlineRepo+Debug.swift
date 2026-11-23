import Foundation
import OSLog
import UnderlineKit

#if DEBUG
/// What the debug sheet shows and does: underlining a whole book, exporting the saved chapters, and why a chapter came out as it did.
extension UnderlineRepo {
    func considered(inChapter chapter: Int, of book: String) -> [ConsideredPhrase] {
        foundConsidered[book]?[chapter] ?? []
    }

    func cloudResult(inChapter chapter: Int, of book: String) -> String? {
        cloudResults[book]?[chapter]
    }

    /// Progress of "Underline whole book", for the debug sheet.
    struct BookRun: Sendable, Equatable {
        let total: Int
        var finished = 0
        var current: Int?
        /// Chapters that weren't saved (stopped), left for the next run.
        var leftOut: [Int] = []
        var isRunning = true
        /// Why the run didn't start, such as the model not answering.
        var refusal: String?
    }

    /// The chapters a whole-book run goes through: from `firstReadableChapterIndex` to the end.
    static func storyChapterCount(of content: BookContent) -> Int {
        content.chapters.count - content.firstReadableChapterIndex
    }

    func bookRun(of book: String) -> BookRun? {
        bookRuns[book]
    }

    /// Where a book's chapters are saved. The folder appears once the first chapter is done.
    func savedFolder(of book: String) -> String {
        folder.appending(path: book).path(percentEncoded: false)
    }

    /// Underlines every chapter from where the story starts (not the cover or copyright page), in order, and saves each
    /// one, so a whole book can be worked out in one go. Chapters already
    /// saved are skipped, so a stopped run carries on where it was. The chapter being read is not touched.
    /// The chapters it saves become the seeds testers get.
    func startBook(_ content: BookContent) async {
        guard bookTask == nil else { return }
        bookRuns[content.fingerprint] = BookRun(total: content.chapters.count)
        logger.info("Whole book: chapters are saved in \(self.savedFolder(of: content.fingerprint), privacy: .public)")
        bookTask = Task { await self.runBook(content) }
    }

    func stopBook() {
        bookTask?.cancel()
    }

    /// What "Export saved chapters" copied: chapter files per book fingerprint, and files left behind because an older
    /// engine made them.
    struct Export: Sendable {
        var chapters: [String: Int] = [:]
        var outdated = 0
    }

    /// Copies the saved chapters of every book into `destination`, one folder per book named by its fingerprint, the way
    /// the seeds bundled with the app are laid out. A file already there is replaced; nothing else in `destination` is
    /// touched. Chapters from an older engine are left out.
    func exportSaved(to destination: URL) throws -> Export {
        let manager = FileManager.default
        var export = Export()
        let books = try manager.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.isDirectoryKey])
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
        for book in books {
            let files = try manager.contentsOfDirectory(at: book, includingPropertiesForKeys: nil)
                .filter { $0.lastPathComponent.hasPrefix("chapter-") && $0.pathExtension == "json" }
            let current = files.filter { file in
                let stored = (try? Data(contentsOf: file)).flatMap { try? JSONDecoder().decode(StoredChapter.self, from: $0) }
                return stored?.engineVersion == UnderlineRepoKnobs.engineVersion
            }
            export.outdated += files.count - current.count
            guard !current.isEmpty else { continue }
            let target = destination.appending(path: book.lastPathComponent)
            try manager.createDirectory(at: target, withIntermediateDirectories: true)
            for file in current {
                let copy = target.appending(path: file.lastPathComponent)
                if manager.fileExists(atPath: copy.path(percentEncoded: false)) { try manager.removeItem(at: copy) }
                try manager.copyItem(at: file, to: copy)
            }
            export.chapters[book.lastPathComponent] = current.count
        }
        logger.info("Exported \(export.chapters.values.reduce(0, +)) chapters of \(export.chapters.count) books to \(destination.path(percentEncoded: false), privacy: .public)")
        return export
    }

    private func runBook(_ content: BookContent) async {
        let book = content.fingerprint
        defer {
            let left = (bookRuns[book]?.leftOut ?? []).map(String.init).joined(separator: ", ")
            logger.info("Whole book ended: \(self.bookRuns[book]?.finished ?? 0) of \(Self.storyChapterCount(of: content)) chapters done, left out: \(left.isEmpty ? "none" : left)")
            bookRuns[book]?.isRunning = false
            bookRuns[book]?.current = nil
            bookTask = nil
        }
        for chapter in content.chapters.indices.dropFirst(content.firstReadableChapterIndex) {
            if Task.isCancelled { return }
            if !isFinished(chapter, of: book, parserVersion: content.parserVersion) {
                let paragraphs = content.chapters[chapter].paragraphs
                // A chapter without sentences has nothing to underline.
                if let first = content.sentences.firstIndex(where: { paragraphs.contains($0.paragraph) }) {
                    bookRuns[book]?.current = chapter
                    logger.info("Whole book: starting chapter \(chapter) of \(content.chapters.count)")
                    let (_, continuation) = AsyncStream<Void>.makeStream()
                    await run(chapter, of: content, startingAt: first, continuation: continuation)
                    if Task.isCancelled { return }
                    guard finishedChapters[book]?.contains(chapter) == true else {
                        bookRuns[book]?.leftOut.append(chapter)
                        continue
                    }
                }
            }
            bookRuns[book]?.finished += 1
        }
    }
}
#endif
