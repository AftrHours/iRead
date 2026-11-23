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

    @Test("Only events after explicit consent are uploaded, while export retains earlier events")
    func consentBoundary() async throws {
        let recorder = recorder()
        recorder.record(.importStarted)
        try recorder.cloudDelivery.setSharing(true)
        recorder.record(.readerReady)
        recorder.cloudDelivery.flush()
        #expect(await eventually { (try? sharedEvents()) == ["readerReady"] })
        #expect(cloud.records(in: .reader).isEmpty)
        let local = try await JSONDecoder().decode(Report.self, from: recorder.export())
        #expect(local.events.map(\.event).contains("importStarted"))
    }

    @Test("Revoking consent discards queued events, including after opting in again")
    func revokeAndReenable() async throws {
        let recorder = recorder()
        cloud.isOffline = true
        try recorder.cloudDelivery.setSharing(true)
        recorder.record(.importFailed)
        recorder.cloudDelivery.flush()
        try recorder.cloudDelivery.setSharing(false)
        recorder.record(.referenceCardOpened)
        cloud.isOffline = false
        try recorder.cloudDelivery.setSharing(true)
        recorder.record(.pageAdvanced)
        recorder.cloudDelivery.flush()
        #expect(await eventually { (try? sharedEvents()) == ["pageAdvanced"] })
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
        try recorder.cloudDelivery.setSharing(true)
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

    @Test("A signed-out batch survives restart and a later flush sends one copy")
    func offlineRelaunch() async throws {
        cloud.isOffline = true
        do {
            let first = recorder()
            try first.cloudDelivery.setSharing(true)
            first.record(.importSucceeded)
            first.cloudDelivery.flush()
            _ = try await first.export()
            #expect(cloud.records(in: .developers).isEmpty)
        }
        cloud.isOffline = false
        let second = recorder()
        #expect(second.cloudDelivery.isSharing)
        second.cloudDelivery.flush()
        #expect(await eventually { (try? sharedEvents().filter { $0 == "importSucceeded" }.count) == 1 })
        second.cloudDelivery.flush()
        #expect(await eventually { (try? sharedEvents().filter { $0 == "appStarted" }.count) == 1 })
        #expect(try sharedEvents().filter { $0 == "importSucceeded" }.count == 1)
    }
}
