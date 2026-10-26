import Foundation

struct SearchResult: Identifiable, Sendable {
    let chapterTitle: String
    let snippet: String
    let position: ReadingPosition
    let pageNumber: Int

    var id: ReadingPosition { position }
}
