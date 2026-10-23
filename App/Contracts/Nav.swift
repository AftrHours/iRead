import Foundation

@MainActor
protocol Nav {
    func openReader(bookID: UUID)
    func closeReader()
}
