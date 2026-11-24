import CryptoKit
import Foundation
import MetricKit
import OSLog

enum BetaEvent: String {
    case appStarted, pickerStarted, pickerCancelled, pickerFailed, importStarted, importSucceeded, importFailed
    case bookOpenRequested, readerReady, openingFailed, sessionStarted, activeReading, pageAdvanced
    case progressSaved, progressSaveFailed, resumeAttempted, resumeSucceeded, resumeFailed
    case underlineDisplayed, referenceCardOpened, jumpCompleted, returnCompleted, ratingChanged
    case recoverableError, pageTurn, repagination, crash
}

struct AnalyticsAttempt: Sendable {
    let id = UUID().uuidString
    let start = ContinuousClock.now

    var milliseconds: Double { start.duration(to: .now).milliseconds }
}

extension Duration {
    var milliseconds: Double {
        Double(components.seconds) * 1_000 + Double(components.attoseconds) / 1e15
    }
}

/// Only these fields can leave the event recorder. Never pass titles, quotes, URLs or raw error messages.
struct BetaRecord: Codable, Sendable {
    let id: String
    let event: String
    let timestamp: Date
    let tester: String
    let launch: String
    let build: String
    let device: String
    let os: String
    var flow: String?
    var picker: String?
    var session: String?
    var reference: String?
    var category: String?
    var feature: String?
    var milliseconds: Double?
    var pid: Int32?
}

/// Records events and hands them to `BetaCloudDelivery`, which sends them without asking. One writer keeps them in order.
final class BetaAnalytics: NSObject, MXMetricManagerSubscriber, @unchecked Sendable {
    static let shared = BetaAnalytics()
    private let queue = DispatchQueue(label: "iRead.beta.events", qos: .utility)
    private let folder: URL
    let cloudDelivery: BetaCloudDelivery
    private let tester: String
    private let launch = UUID().uuidString
    private let build: String
    private let device: String
    private let os = ProcessInfo.processInfo.operatingSystemVersionString
    private let enabled: Bool
    private let logger = Logger(subsystem: Logger.appSubsystem, category: "betaAnalytics")

    override convenience init() {
        let environment = ProcessInfo.processInfo.environment
        let enabled = environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" && NSClassFromString("XCTestCase") == nil
            && environment["XCTestConfigurationFilePath"] == nil
        let defaults = UserDefaults.standard
        let tester = defaults.string(forKey: "betaAnalyticsInstall") ?? UUID().uuidString
        if enabled { defaults.set(tester, forKey: "betaAnalyticsInstall") }
        self.init(folder: URL.applicationSupportDirectory.appending(path: "BetaAnalytics"), tester: tester, enabled: enabled)
        if enabled {
            removeTestFlightFiles()
            MXMetricManager.shared.add(self)
        }
    }

    init(folder: URL, tester: String, enabled: Bool) {
        self.folder = folder
        cloudDelivery = BetaCloudDelivery(folder: folder, queue: queue)
        self.tester = tester
        self.enabled = enabled
        build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
        var system = utsname()
        uname(&system)
        device = withUnsafeBytes(of: &system.machine) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
        super.init()
        if enabled {
            record(.appStarted, pid: ProcessInfo.processInfo.processIdentifier)
        }
    }

    func referenceKey(book: UUID, id: String) -> String {
        Self.digest(Data("\(tester)|\(book)|\(id)".utf8))
    }

    private static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    func record(_ event: BetaEvent, flow: String? = nil, picker: String? = nil, session: String? = nil, reference: String? = nil,
                category: String? = nil, feature: String? = nil, milliseconds: Double? = nil, pid: Int32? = nil) {
        guard enabled else { return }
        append(BetaRecord(id: UUID().uuidString, event: event.rawValue, timestamp: .now, tester: tester,
                          launch: launch, build: build, device: device, os: os, flow: flow, picker: picker, session: session,
                          reference: reference, category: category, feature: feature, milliseconds: milliseconds, pid: pid))
    }

    static func category(_ error: Error) -> String {
        switch error {
        case ImportError.alreadyInLibrary: "duplicate"
        case ImportError.tooLarge: "too_large"
        case ImportError.unreachable, is URLError: "network"
        case ContentError.notFound: "missing_file"
        case ContentError.unreadable, is DecodingError: "invalid_content"
        case is CocoaError: "file_access"
        default: "other"
        }
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            for (index, crash) in (payload.crashDiagnostics ?? []).enumerated() {
                let metadata = crash.metaData
                // A redelivered payload must count once, even across exports and launches.
                let canonical = (try? JSONSerialization.data(withJSONObject: payload.dictionaryRepresentation(), options: [.sortedKeys]))
                    ?? payload.jsonRepresentation()
                let key = Self.digest(canonical) + "-\(index)"
                append(BetaRecord(id: key, event: BetaEvent.crash.rawValue, timestamp: payload.timeStampEnd,
                                  tester: tester, launch: "", build: metadata.applicationBuildVersion, device: metadata.deviceType,
                                  os: metadata.osVersion, category: crash.signal?.stringValue, pid: metadata.pid))
            }
        }
    }

    private func append(_ record: BetaRecord) {
        queue.async { [self] in
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .millisecondsSince1970
                try cloudDelivery.append(try encoder.encode(record))
            } catch {
                logger.error("Could not queue a beta analytics event.")
            }
        }
    }

    /// TestFlight builds kept every event in events.jsonl for export, and asked before sharing (sharing.json, one outbox
    /// folder per answer). Neither is used now.
    private func removeTestFlightFiles() {
        queue.async { [folder] in
            let files = FileManager.default
            let old = (try? files.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
            for url in old where ["events.jsonl", "sharing.json"].contains(url.lastPathComponent)
                || UUID(uuidString: url.lastPathComponent) != nil {
                try? files.removeItem(at: url)
            }
        }
    }
}
