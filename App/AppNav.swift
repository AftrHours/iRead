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

    private(set) var openAttempt: AnalyticsAttempt?

    func openReader(book: BookRecord) {
        let attempt = AnalyticsAttempt()
        openAttempt = attempt
        BetaAnalytics.shared.record(.bookOpenRequested, flow: attempt.id)
        route = .reader(book: book)
    }

    func closeReader() {
        openAttempt = nil
        route = .library
    }
}
