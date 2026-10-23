import Foundation
import Observation

@MainActor
@Observable
final class AppNav {
    enum Route {
        case library
        case reader(bookID: UUID)
    }

    private(set) var route = Route.library

    func openReader(bookID: UUID) {
        route = .reader(bookID: bookID)
    }

    func closeReader() {
        route = .library
    }
}
