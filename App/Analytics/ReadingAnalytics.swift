import Foundation

/// A reading session runs from the first usable page until this reader closes.
/// Time accrues only in the foreground, for at most two minutes after the last interaction.
@MainActor
final class ReadingAnalytics {
    let session = UUID().uuidString
    let book: UUID
    private let attempt: AnalyticsAttempt?
    private(set) var ready = false
    private var didFail = false
    private var seen: Set<String> = []
    private var active = false
    private var lastActivity: ContinuousClock.Instant?
    private var accountedThrough: ContinuousClock.Instant?
    private var checkpoint: Task<Void, Never>?
    private struct Navigation {
        let event: BetaEvent
        let page: Page
        let flow: String?
        let reference: String?
        let attempt: AnalyticsAttempt
    }
    private var navigation: Navigation?
    private var renderedPage: Page?
    private var turnStart: ContinuousClock.Instant?
    private let sink: BetaAnalytics

    init(book: UUID, attempt: AnalyticsAttempt?, sink: BetaAnalytics = .shared) {
        self.sink = sink
        self.book = book
        self.attempt = attempt
    }

    func pageVisible(_ page: Page) {
        renderedPage = page
        finishNavigationIfVisible()
        guard !ready, !didFail else { return }
        ready = true
        if let attempt {
            sink.record(.readerReady, flow: attempt.id, session: session, milliseconds: attempt.milliseconds)
        }
        sink.record(.sessionStarted, flow: attempt?.id, session: session)
        if active { startClock() }
    }

    func navigating(_ event: BetaEvent, to page: Page, flow: String?, reference: String? = nil, attempt: AnalyticsAttempt) {
        navigation = Navigation(event: event, page: page, flow: flow, reference: reference, attempt: attempt)
        finishNavigationIfVisible()
    }

    private func finishNavigationIfVisible() {
        guard let navigation, renderedPage == navigation.page else { return }
        self.navigation = nil
        record(navigation.event, flow: navigation.flow, reference: navigation.reference, milliseconds: navigation.attempt.milliseconds)
    }

    func openingFailed(_ error: Error) {
        guard !ready, !didFail, let attempt else { return }
        didFail = true
        sink.record(.openingFailed, flow: attempt.id, category: BetaAnalytics.category(error),
                    feature: "open", milliseconds: attempt.milliseconds)
    }

    func setActive(_ value: Bool) {
        guard active != value else { return }
        active = value
        if value {
            if ready { startClock() }
        } else {
            flush()
            lastActivity = nil
            accountedThrough = nil
            turnStart = nil
            checkpoint?.cancel()
            checkpoint = nil
        }
    }

    private func startClock() {
        activity()
        checkpoint?.cancel()
        checkpoint = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(30)) } catch { return }
                self?.flush()
            }
        }
    }

    func activity() {
        guard ready, active else { return }
        let now = ContinuousClock.now
        flush(at: now)
        lastActivity = now
        accountedThrough = now
    }

    private func flush(at now: ContinuousClock.Instant = .now) {
        guard let lastActivity, let accountedThrough else { return }
        let end = min(now, lastActivity.advanced(by: .seconds(120)))
        guard end > accountedThrough else { return }
        sink.record(.activeReading, session: session, milliseconds: accountedThrough.duration(to: end).milliseconds)
        self.accountedThrough = end
    }

    func visible(_ ids: [String]) {
        guard ready, active else { return }
        for id in ids where seen.insert(id).inserted {
            record(.underlineDisplayed, reference: id)
        }
    }

    func turnBegan() {
        turnStart = .now
        activity()
    }

    func turned(forward: Bool) {
        activity()
        if let turnStart {
            record(.pageTurn, milliseconds: turnStart.duration(to: .now).milliseconds)
        }
        turnStart = nil
        if forward { record(.pageAdvanced) }
    }

    func record(_ event: BetaEvent, flow: String? = nil, reference: String? = nil,
                category: String? = nil, feature: String? = nil, milliseconds: Double? = nil) {
        sink.record(event, flow: flow, session: session, reference: reference.map { sink.referenceKey(book: book, id: $0) },
                    category: category, feature: feature, milliseconds: milliseconds)
    }
}
