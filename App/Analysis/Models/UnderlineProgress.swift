import Foundation

/// How far `UnderlineRepo` has got with one book.
struct UnderlineProgress: Sendable {
    enum Phase: Equatable, Sendable {
        case loading
        case working(chapter: Int)
        /// Waiting because the device is hot or in Low Power Mode.
        case paused
        case finished
        /// `availability` said yes but a test call failed. Tried again the next time the book opens.
        case modelNotAnswering
        case stopped
    }

    var phase = Phase.loading
    var usesModel = false
    var chapterCount = 0
    var doneChapters: Set<Int> = []
    var workingSince: Date?
}
