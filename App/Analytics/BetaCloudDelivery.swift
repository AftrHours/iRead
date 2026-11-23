import Foundation
import OSLog

/// Access to the journal and outbox is serialized on the recorder's queue.
final class BetaCloudDelivery: @unchecked Sendable {
    private struct Consent: Codable {
        let id: UUID
        let since: Date
    }

    private let folder: URL
    private let queue: DispatchQueue
    private let files = FileManager.default
    private let logger = Logger(subsystem: Logger.appSubsystem, category: "betaCloud")
    private var cloud: (any CloudSvc)?
    private var consent: Consent?
    private var timer: DispatchWorkItem?
    private var upload: Task<Void, Never>?
    private var retryDelay = 15
    private var consentFile: URL { folder.appending(path: "sharing.json") }

    init(folder: URL, queue: DispatchQueue) {
        self.folder = folder
        self.queue = queue
        consent = (try? Data(contentsOf: folder.appending(path: "sharing.json")))
            .flatMap { try? JSONDecoder().decode(Consent.self, from: $0) }
    }

    var isSharing: Bool { queue.sync { consent != nil } }
    var isAvailable: Bool { queue.sync { cloud != nil } }

    func connect(_ service: (any CloudSvc)?) {
        queue.sync {
            cloud = service
            schedule(after: 1)
        }
    }

    func setSharing(_ enabled: Bool) throws {
        try queue.sync {
            guard enabled != (consent != nil) else { return }
            if enabled {
                guard cloud != nil else { throw CocoaError(.featureUnsupported) }
                let choice = Consent(id: UUID(), since: .now)
                try files.createDirectory(at: folder, withIntermediateDirectories: true)
                var location = folder
                var flags = URLResourceValues()
                flags.isExcludedFromBackup = true
                try location.setResourceValues(flags)
                try JSONEncoder().encode(choice).write(to: consentFile, options: .atomic)
                consent = choice
            } else if let previous = consent {
                try files.removeItem(at: consentFile)
                consent = nil
                timer?.cancel()
                timer = nil
                upload?.cancel()
                upload = nil
                retryDelay = 15
                let directory = outbox(previous)
                if files.fileExists(atPath: directory.path) { try files.removeItem(at: directory) }
            }
        }
    }

    private func outbox(_ choice: Consent) -> URL {
        folder.appending(path: choice.id.uuidString, directoryHint: .isDirectory)
    }

    /// Called on the recorder's queue. Only newly observed, consented events enter this outbox.
    func append(_ bytes: Data, observedFrom date: Date) throws {
        dispatchPrecondition(condition: .onQueue(queue))
        guard let consent, date >= consent.since else { return }
        let directory = outbox(consent)
        try files.createDirectory(at: directory, withIntermediateDirectories: true)
        let draft = directory.appending(path: "draft")
        var batch = files.fileExists(atPath: draft.path) ? try Data(contentsOf: draft) : Data()
        if !batch.isEmpty { batch.append(10) }
        batch.append(bytes)
        try batch.write(to: draft, options: .atomic)
        if batch.count >= 32_768 { _ = try seal(draft) }
        schedule(after: 10)
    }

    /// Once sealed, a batch keeps the same contents and record name across retries and relaunches.
    private func seal(_ draft: URL) throws -> URL {
        let sealed = draft.deletingLastPathComponent().appending(path: UUID().uuidString + ".batch")
        try files.moveItem(at: draft, to: sealed)
        return sealed
    }

    private func nextBatch(in directory: URL) throws -> URL? {
        guard files.fileExists(atPath: directory.path) else { return nil }
        let queued = try files.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        if let sealed = queued.first(where: { $0.pathExtension == "batch" }) { return sealed }
        let draft = directory.appending(path: "draft")
        return files.fileExists(atPath: draft.path) ? try seal(draft) : nil
    }

    private func schedule(after seconds: Int) {
        guard consent != nil, cloud != nil, timer == nil, upload == nil else { return }
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
        guard let consent, let cloud, upload == nil else { return }
        do {
            guard let batch = try nextBatch(in: outbox(consent)) else { return }
            let lines = try String(contentsOf: batch, encoding: .utf8).split(separator: "\n")
            let report = #"{"schemaVersion":1,"events":["# + lines.joined(separator: ",") + "]}"
            let name = "beta-" + batch.deletingPathExtension().lastPathComponent
            upload = Task { [weak self] in
                do {
                    guard await cloud.account() == .signedIn else { throw URLError(.userAuthenticationRequired) }
                    try Task.checkCancellation()
                    try await cloud.save(["report": .text(report)], asRecord: name, ofType: "BetaAnalyticsBatch", in: .developers)
                    self?.finished(batch, choice: consent.id, saved: true)
                } catch {
                    self?.finished(batch, choice: consent.id, saved: false)
                }
            }
        } catch {
            retry()
        }
    }

    private func finished(_ batch: URL, choice: UUID, saved: Bool) {
        queue.async { [self] in
            guard consent?.id == choice else { return }
            upload = nil
            do {
                if saved {
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
