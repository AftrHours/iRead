import CloudKit
import Foundation

enum CloudValue: Sendable, Equatable {
    case text(String)
    case number(Int)
    case bytes(Data)
}

enum CloudAccount: Sendable, Equatable {
    case signedIn, signedOut, restricted
    /// Offline, or iCloud is busy.
    case unknown
}

enum CloudDatabase: Sendable, Hashable {
    /// The reader's private database. Counts against their iCloud storage.
    case reader
    /// The public database, read by the developers in the CloudKit Console.
    case developers
}

/// A protocol so tests never reach iCloud.
protocol CloudSvc: Sendable {
    func account() async -> CloudAccount
    /// nil when there's no such record.
    func record(named name: String, in database: CloudDatabase) async throws -> [String: CloudValue]?
    /// Replaces any record with the same name.
    func save(_ fields: [String: CloudValue], asRecord name: String, ofType type: String, in database: CloudDatabase) async throws
    /// A missing record isn't an error.
    func deleteRecord(named name: String, in database: CloudDatabase) async throws
}

enum CloudSvcKnobs {
    /// Must match the container in project.yml's entitlements.
    static let containerID = "iCloud.com.aftrhours.reader"
    /// Seconds to wait before carrying on without iCloud.
    static let timeout: TimeInterval = 10
}

struct CloudSvcCloudKit: CloudSvc {
    private let container = CKContainer(identifier: CloudSvcKnobs.containerID)

    func account() async -> CloudAccount {
        switch try? await container.accountStatus() {
        case .available: .signedIn
        case .noAccount: .signedOut
        case .restricted: .restricted
        default: .unknown
        }
    }

    func record(named name: String, in database: CloudDatabase) async throws -> [String: CloudValue]? {
        do {
            return try await run(in: database) { database in
                let record = try await database.record(for: CKRecord.ID(recordName: name))
                var fields: [String: CloudValue] = [:]
                for key in record.allKeys() {
                    if let text = record[key] as? String {
                        fields[key] = .text(text)
                    } else if let number = record[key] as? Int {
                        fields[key] = .number(number)
                    } else if let data = record[key] as? Data {
                        fields[key] = .bytes(data)
                    }
                }
                return fields
            }
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        }
    }

    func save(_ fields: [String: CloudValue], asRecord name: String, ofType type: String, in database: CloudDatabase) async throws {
        try await run(in: database) { database in
            let record = CKRecord(recordType: type, recordID: CKRecord.ID(recordName: name))
            for (key, value) in fields {
                switch value {
                case .text(let text): record[key] = text
                case .number(let number): record[key] = number
                case .bytes(let data): record[key] = data
                }
            }
            // .allKeys overwrites without fetching the saved record first.
            let (saved, _) = try await database.modifyRecords(saving: [record], deleting: [], savePolicy: .allKeys)
            guard let result = saved[record.recordID] else { throw CKError(.internalError) }
            _ = try result.get()
        }
    }

    func deleteRecord(named name: String, in database: CloudDatabase) async throws {
        do {
            _ = try await run(in: database) { try await $0.deleteRecord(withID: CKRecord.ID(recordName: name)) }
        } catch let error as CKError where error.code == .unknownItem {}
    }

    private func run<Result: Sendable>(in database: CloudDatabase,
                                       _ body: @Sendable (CKDatabase) async throws -> Result) async throws -> Result {
        let configuration = CKOperation.Configuration()
        configuration.timeoutIntervalForRequest = CloudSvcKnobs.timeout
        let chosen = database == .reader ? container.privateCloudDatabase : container.publicCloudDatabase
        return try await chosen.configuredWith(configuration: configuration, body: body)
    }
}
