import Foundation
import OSLog

enum BetaCloudDeliveryKnobs {
    /// A batch is sealed and sent at this size.
    static let batchBytes = 32_768
    /// Batches kept while they can't be sent (offline, or not signed in to iCloud); the oldest go first.
    static let maxQueuedBatches = 30
}

/// Sends the recorder's events to the developers' CloudKit public database as `BetaAnalyticsBatch` records, without asking:
/// anonymous usage, performance and crash events, never titles, passages or search terms. Needs iCloud on the device.
/// Access to the outbox is serialized on the recorder's queue.
final class BetaCloudDelivery: @unchecked Sendable {
    private let outbox: URL
    private let queue: DispatchQueue
    private let files = FileManager.default
    private let logger = Logger(subsystem: Logger.appSubsystem, category: "betaCloud")
    private var cloud: (any CloudSvc)?
    private var timer: DispatchWorkItem?
    private var upload: Task<Void, Never>?
    private var retryDelay = 15
    #if DEBUG
    private var lastResult: String?

    /// For the debug sheet: what's waiting and how the last send went.
    var status: String {
        queue.sync {
            guard cloud != nil else { return "no iCloud in this build" }
            let waiting = ((try? files.contentsOfDirectory(atPath: outbox.path)) ?? []).count
            return "\(waiting) waiting to send" + (lastResult.map { " · \($0)" } ?? "")
        }
    }
    #endif

    init(folder: URL, queue: DispatchQueue) {
        outbox = folder.appending(path: "outbox", directoryHint: .isDirectory)
        self.queue = queue
    }

    func connect(_ service: (any CloudSvc)?) {
        queue.sync {
            cloud = service
            schedule(after: 1)
        }
    }

    /// Called on the recorder's queue.
    func append(_ bytes: Data) throws {
        dispatchPrecondition(condition: .onQueue(queue))
        if !files.fileExists(atPath: outbox.path) {
            try files.createDirectory(at: outbox, withIntermediateDirectories: true)
            var location = outbox
            var flags = URLResourceValues()
            flags.isExcludedFromBackup = true
            try location.setResourceValues(flags)
        }
        let draft = outbox.appending(path: "draft")
        var batch = files.fileExists(atPath: draft.path) ? try Data(contentsOf: draft) : Data()
        if !batch.isEmpty { batch.append(10) }
        batch.append(bytes)
        try batch.write(to: draft, options: .atomic)
        if batch.count >= BetaCloudDeliveryKnobs.batchBytes {
            _ = try seal(draft)
            try dropOldestBatches()
        }
        schedule(after: 10)
    }

    /// Once sealed, a batch keeps the same contents and record name across retries and relaunches.
    private func seal(_ draft: URL) throws -> URL {
        // Named oldest first: the time it was sealed, then a random part.
        let name = String(format: "%013.0f", Date.now.timeIntervalSince1970 * 1000) + "-" + UUID().uuidString
        let sealed = draft.deletingLastPathComponent().appending(path: name + ".batch")
        try files.moveItem(at: draft, to: sealed)
        return sealed
    }

    private func sealedBatches() throws -> [URL] {
        try files.contentsOfDirectory(at: outbox, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "batch" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private func dropOldestBatches() throws {
        for batch in try sealedBatches().dropLast(BetaCloudDeliveryKnobs.maxQueuedBatches) {
            try files.removeItem(at: batch)
        }
    }

    private func nextBatch() throws -> URL? {
        guard files.fileExists(atPath: outbox.path) else { return nil }
        if let sealed = try sealedBatches().first { return sealed }
        let draft = outbox.appending(path: "draft")
        return files.fileExists(atPath: draft.path) ? try seal(draft) : nil
    }

    private func schedule(after seconds: Int) {
        guard cloud != nil, timer == nil, upload == nil else { return }
        let item = DispatchWorkItem { [weak self] in
            self?.timer = nil
            self?.sendNext()
        }
        timer = item
        queue.asyncAfter(deadline: .now() + .seconds(seconds), execute: item)
    }

    func flush() {
        queue.async { [self] in
            timer?.cancel()
            timer = nil
            sendNext()
        }
    }

    private func sendNext() {
        guard let cloud, upload == nil else { return }
        do {
            guard let batch = try nextBatch() else { return }
            let lines = try String(contentsOf: batch, encoding: .utf8).split(separator: "\n")
            let report = #"{"schemaVersion":1,"events":["# + lines.joined(separator: ",") + "]}"
            let name = "beta-" + batch.deletingPathExtension().lastPathComponent
            upload = Task { [weak self] in
                do {
                    guard await cloud.account() == .signedIn else { throw URLError(.userAuthenticationRequired) }
                    try Task.checkCancellation()
                    try await cloud.save(["report": .text(report)], asRecord: name, ofType: "BetaAnalyticsBatch", in: .developers)
                    self?.finished(batch, error: nil)
                } catch {
                    self?.finished(batch, error: error)
                }
            }
        } catch {
            retry()
        }
    }

    private func finished(_ batch: URL, error: Error?) {
        queue.async { [self] in
            upload = nil
            #if DEBUG
            let time = Date.now.formatted(date: .omitted, time: .standard)
            if let error {
                let reason = (error as? URLError)?.code == .userAuthenticationRequired ? "not signed in to iCloud" : error.localizedDescription
                lastResult = "couldn't send at \(time): \(reason)"
            } else {
                lastResult = "sent at \(time)"
            }
            #endif
            do {
                if error == nil {
                    try files.removeItem(at: batch)
                    retryDelay = 15
                    schedule(after: 0)
                } else {
                    retry()
                }
            } catch {
                retry()
            }
        }
    }

    private func retry() {
        logger.debug("Beta analytics batch pending. Retrying later.")
        schedule(after: retryDelay)
        retryDelay = min(retryDelay * 2, 900)
    }
}
