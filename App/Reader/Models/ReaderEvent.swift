import Foundation

enum ReaderEvent: Sendable {
    case positionRestore(bookID: UUID, isRestored: Bool)
    case bookFinished(bookID: UUID)
}
