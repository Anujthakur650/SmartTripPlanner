import Foundation
#if canImport(CloudKit)
import CloudKit
#endif

struct CloudChangePayload: Equatable {
    let entityName: String
    let recordIdentifier: String
    let payload: Data
    let modifiedAt: Date
}

struct CloudDeletionPayload: Equatable {
    let entityName: String
    let recordIdentifier: String
    let deletedAt: Date
}

struct CloudPullResponse: Equatable {
    var updated: [CloudChangePayload]
    var deleted: [CloudDeletionPayload]
    var serverChangeToken: Data?
}

protocol CloudKitSyncAdapter {
    func push(changes: [CloudChangePayload], deletions: [CloudDeletionPayload]) async throws
    func pull(since: Date?, serverChangeToken: Data?) async throws -> CloudPullResponse
}

final class NoopCloudKitSyncAdapter: CloudKitSyncAdapter {
    private var storage: [String: CloudChangePayload] = [:]
    private var deletions: [String: CloudDeletionPayload] = [:]
    private let lock = NSLock()

    func push(changes: [CloudChangePayload], deletions: [CloudDeletionPayload]) async throws {
        lock.lock()
        defer { lock.unlock() }
        for change in changes {
            storage[change.recordIdentifier] = change
            self.deletions.removeValue(forKey: change.recordIdentifier)
        }
        for deletion in deletions {
            storage.removeValue(forKey: deletion.recordIdentifier)
            self.deletions[deletion.recordIdentifier] = deletion
        }
    }

    func pull(since: Date?, serverChangeToken: Data?) async throws -> CloudPullResponse {
        lock.lock()
        defer { lock.unlock() }
        let updated = storage.values
            .filter { payload in
                guard let since else { return true }
                return payload.modifiedAt >= since
            }
            .sorted(by: { $0.modifiedAt < $1.modifiedAt })
        let deleted = deletions.values
            .filter { deletion in
                guard let since else { return true }
                return deletion.deletedAt >= since
            }
            .sorted(by: { $0.deletedAt < $1.deletedAt })
        return CloudPullResponse(updated: updated, deleted: deleted, serverChangeToken: serverChangeToken)
    }
}

#if canImport(CloudKit)
final class CloudKitMirroringAdapter: CloudKitSyncAdapter {
    private let database: CKDatabase
    private let zoneID: CKRecordZone.ID

    init(containerIdentifier: String, databaseScope: CKDatabase.Scope = .private) {
        let container = CKContainer(identifier: containerIdentifier)
        self.database = container.database(with: databaseScope)
        self.zoneID = CKRecordZone.default().zoneID
    }

    func push(changes: [CloudChangePayload], deletions: [CloudDeletionPayload]) async throws {
        guard !changes.isEmpty || !deletions.isEmpty else { return }
        let records = try changes.map { change -> CKRecord in
            let recordID = CKRecord.ID(recordName: change.recordIdentifier, zoneID: zoneID)
            let record = CKRecord(recordType: change.entityName, recordID: recordID)
            record["payload"] = change.payload as CKRecordValue
            record["modifiedAt"] = change.modifiedAt as CKRecordValue
            return record
        }
        let recordIDs = deletions.map { deletion in
            CKRecord.ID(recordName: deletion.recordIdentifier, zoneID: zoneID)
        }
        _ = try await database.modifyRecords(
            saving: records,
            deleting: recordIDs,
            savePolicy: .allKeys,
            atomically: false
        )
    }

    func pull(since: Date?, serverChangeToken: Data?) async throws -> CloudPullResponse {
        let query = CKQuery(recordType: "TripDataRecord", predicate: NSPredicate(value: true))
        if let since {
            query.predicate = NSPredicate(format: "modifiedAt >= %@", since as NSDate)
        }
        let result = try await database.records(matching: query)
        var updated: [CloudChangePayload] = []
        result.matchResults.forEach { _, matchResult in
            if case let .success(record) = matchResult,
               let payload = record["payload"] as? Data,
               let modifiedAt = record["modifiedAt"] as? Date {
                let change = CloudChangePayload(
                    entityName: record.recordType,
                    recordIdentifier: record.recordID.recordName,
                    payload: payload,
                    modifiedAt: modifiedAt
                )
                updated.append(change)
            }
        }
        return CloudPullResponse(updated: updated, deleted: [], serverChangeToken: serverChangeToken)
    }
}
#endif
