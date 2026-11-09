import Foundation
import Synchronization
@testable import iRead

/// Counts logged events.
final class EventSvcSpy: EventSvc {
    private let logged = Mutex<[ReaderEvent]>([])

    var events: [ReaderEvent] {
        logged.withLock { $0 }
    }

    var finishedCount: Int {
        events.count { if case .bookFinished = $0 { true } else { false } }
    }

    func log(_ event: ReaderEvent) async {
        logged.withLock { $0.append(event) }
    }
}

/// Counts parses. Returns `content` if given, otherwise parses the real file. The first `failures` parses throw.
final class EPUBParseSvcSpy: EPUBParseSvc {
    private let real = EPUBParseSvcEPUBKit()
    private let content: BookContent?
    private let state: Mutex<(parses: Int, failuresLeft: Int)>

    init(content: BookContent? = nil, failures: Int = 0) {
        self.content = content
        state = Mutex((0, failures))
    }

    var parseCount: Int {
        state.withLock { $0.parses }
    }

    func metadata(from url: URL) throws -> (title: String?, author: String?, identifiers: [String]) {
        try real.metadata(from: url)
    }

    func cover(from url: URL) throws -> Data? {
        try real.cover(from: url)
    }

    func parse(_ url: URL) async throws -> BookContent {
        let fails = state.withLock { state in
            state.parses += 1
            guard state.failuresLeft > 0 else { return false }
            state.failuresLeft -= 1
            return true
        }
        // A short wait, so concurrent callers really overlap.
        try await Task.sleep(for: .milliseconds(20))
        if fails { throw ContentError.unreadable }
        if let content { return content }
        return try await real.parse(url)
    }
}

/// Splits text every `pageLength` UTF-16 characters, whatever the settings, and counts layouts.
final class PagerSvcFixed: PagerSvc {
    private let pageLength: Int
    private let layouts = Mutex(0)

    init(pageLength: Int) {
        self.pageLength = pageLength
    }

    var layoutCount: Int {
        layouts.withLock { $0 }
    }

    func pageRanges(for text: String, viewport: Viewport, settings: ReadingSettings) async -> [NSRange] {
        layouts.withLock { $0 += 1 }
        let length = text.utf16.count
        guard length > 0 else { return [NSRange(location: 0, length: 0)] }
        return stride(from: 0, to: length, by: pageLength).map { NSRange(location: $0, length: min(pageLength, length - $0)) }
    }
}

/// Keeps records in memory, as iCloud would. While `isOffline`, every call fails, like a device that isn't signed in.
/// Each save waits `saveDelay`, like a slow network.
final class CloudSvcFake: CloudSvc {
    private let state = Mutex<(records: [CloudDatabase: [String: [String: CloudValue]]], isOffline: Bool)>(([:], false))
    private let saveDelay: Duration

    init(saveDelay: Duration = .zero) {
        self.saveDelay = saveDelay
    }

    /// Signed out while offline, as the app sees a device without iCloud.
    func account() async -> CloudAccount {
        isOffline ? .signedOut : .signedIn
    }

    var isOffline: Bool {
        get { state.withLock { $0.isOffline } }
        set { state.withLock { $0.isOffline = newValue } }
    }

    func records(in database: CloudDatabase) -> [String: [String: CloudValue]] {
        state.withLock { $0.records[database] ?? [:] }
    }

    func record(named name: String, in database: CloudDatabase) async throws -> [String: CloudValue]? {
        try state.withLock { state in
            if state.isOffline { throw URLError(.notConnectedToInternet) }
            return state.records[database]?[name]
        }
    }

    func save(_ fields: [String: CloudValue], asRecord name: String, ofType type: String, in database: CloudDatabase) async throws {
        try await Task.sleep(for: saveDelay)
        try state.withLock { state in
            if state.isOffline { throw URLError(.notConnectedToInternet) }
            state.records[database, default: [:]][name] = fields
        }
    }

    func deleteRecord(named name: String, in database: CloudDatabase) async throws {
        try state.withLock { state in
            if state.isOffline { throw URLError(.notConnectedToInternet) }
            state.records[database]?[name] = nil
        }
    }
}
