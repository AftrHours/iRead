import Foundation
import Observation

@MainActor
@Observable
final class AppNav {
    enum Route: Equatable {
        case library
        case reader(book: BookRecord)
    }

    private(set) var route = Route.library

    func openReader(book: BookRecord) {
        route = .reader(book: book)
    }

    func closeReader() {
        route = .library
    }
}
