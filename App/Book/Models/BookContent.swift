import Foundation

struct BookContent: Sendable {
    let chapters: [Chapter]
    let paragraphs: [Paragraph]
    let sentences: [Sentence]
    let parserVersion: Int
    /// See BookFingerprint.
    let fingerprint: String
    /// Where a first-time reader starts: the chapter after the cover, copyright page and the like. See FirstChapter.
    /// Worked out when the book is opened, never saved, so it doesn't change the chapters or the stored underlines.
    var firstReadableChapterIndex = 0
}
