import Foundation
import Testing
@testable import iRead

@Suite("CloudKit beta analytics")
struct BetaCloudDeliveryTests {
    private let folder = TempFolder()
    private let cloud = CloudSvcFake()

    private func recorder() -> BetaAnalytics {
        let recorder = BetaAnalytics(folder: folder.url, tester: "test-install", enabled: true)
        recorder.cloudDelivery.connect(cloud)
        return recorder
    }

    private func sharedEvents() throws -> [String] {
        try cloud.records(in: .developers).values.flatMap { fields -> [String] in
            guard case .text(let text) = fields["report"] else { return [] }
            let report = try JSONDecoder().decode(Report.self, from: Data(text.utf8))
            return report.events.map(\.event)
        }
    }

    private struct Report: Decodable {
        struct Entry: Decodable { let event: String }
        let events: [Entry]
    }

    @Test("Events are sent without asking, only to the developers' database")
    func sentWithoutAsking() async throws {
        let recorder = recorder()
        recorder.record(.importStarted)
        recorder.record(.readerReady)
        recorder.cloudDelivery.flush()
        #expect(await eventually { Set((try? sharedEvents()) ?? []).isSuperset(of: ["appStarted", "importStarted", "readerReady"]) })
        #expect(cloud.records(in: .reader).isEmpty)
    }

    private actor LostAcknowledgement: CloudSvc {
        let storage = CloudSvcFake()
        private(set) var names: [String] = []

        func account() async -> CloudAccount { .signedIn }
        func record(named name: String, in database: CloudDatabase) async throws -> [String: CloudValue]? {
            try await storage.record(named: name, in: database)
        }
        func deleteRecord(named name: String, in database: CloudDatabase) async throws {
            try await storage.deleteRecord(named: name, in: database)
        }
        func save(_ fields: [String: CloudValue], asRecord name: String, ofType type: String,
                  in database: CloudDatabase) async throws {
            try await storage.save(fields, asRecord: name, ofType: type, in: database)
            names.append(name)
            if names.count == 1 { throw URLError(.networkConnectionLost) }
        }
    }

    @Test("A retry after a lost acknowledgement overwrites the original CloudKit batch")
    func stableRecordOnRetry() async throws {
        let destination = LostAcknowledgement()
        let recorder = recorder()
        recorder.cloudDelivery.connect(destination)
        recorder.record(.referenceCardOpened)
        recorder.cloudDelivery.flush()
        #expect(await eventually { await destination.names.count == 1 })
        #expect(await eventually {
            recorder.cloudDelivery.flush()
            return await destination.names.count >= 2
        })
        let names = await destination.names
        #expect(Set(names).count == 1)
        #expect(destination.storage.records(in: .developers).count == 1)
    }

    @Test("A batch kept while signed out survives a restart and is sent once")
    func offlineRelaunch() async throws {
        cloud.isOffline = true
        do {
            let first = recorder()
            first.record(.importSucceeded)
            first.cloudDelivery.flush()
            #expect(await eventually(within: 1) { !cloud.records(in: .developers).isEmpty } == false)
        }
        cloud.isOffline = false
        let second = recorder()
        second.cloudDelivery.flush()
        #expect(await eventually { (try? sharedEvents().filter { $0 == "importSucceeded" }.count) == 1 })
        second.cloudDelivery.flush()
        #expect(await eventually { (try? sharedEvents().filter { $0 == "appStarted" }.count) == 2 })
        #expect(try sharedEvents().filter { $0 == "importSucceeded" }.count == 1)
    }

    @Test("While events can't be sent, only the newest batches are kept")
    func queueLimit() async throws {
        cloud.isOffline = true
        let recorder = recorder()
        let large = String(repeating: "x", count: BetaCloudDeliveryKnobs.batchBytes)
        let batches = BetaCloudDeliveryKnobs.maxQueuedBatches + 5
        for _ in 0..<batches { recorder.record(.recoverableError, category: large) }
        let outbox = folder.url.appending(path: "outbox")
        let sealed = { (try? FileManager.default.contentsOfDirectory(atPath: outbox.path))?.filter { $0.hasSuffix(".batch") }.count }
        #expect(await eventually { sealed() == BetaCloudDeliveryKnobs.maxQueuedBatches })
    }
}
