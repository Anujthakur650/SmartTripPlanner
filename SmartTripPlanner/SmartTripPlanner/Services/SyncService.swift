import Foundation
import CloudKit

@MainActor
final class SyncService: ObservableObject {
    enum SyncStatus {
        case idle
        case syncing
        case success
        case failed(Error)
    }
    
    enum SyncServiceError: LocalizedError {
        case missingPayload
        case decodingFailed(Error)
        
        var errorDescription: String? {
            switch self {
            case .missingPayload:
                return "Missing payload data from CloudKit record."
            case .decodingFailed(let error):
                return "Failed to decode CloudKit record: \(error.localizedDescription)"
            }
        }
    }
    
    @Published private(set) var syncStatus: SyncStatus = .idle
    @Published private(set) var lastSyncDate: Date?
    
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private let sharedDatabase: CKDatabase
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private weak var appEnvironment: AppEnvironment?
    
    init(
        container: CKContainer = .default(),
        appEnvironment: AppEnvironment? = nil,
        encoder: JSONEncoder? = nil,
        decoder: JSONDecoder? = nil
    ) {
        self.container = container
        self.privateDatabase = container.privateCloudDatabase
        self.sharedDatabase = container.sharedCloudDatabase
        self.encoder = encoder ?? SyncService.makeEncoder()
        self.decoder = decoder ?? SyncService.makeDecoder()
        self.appEnvironment = appEnvironment
    }
    
    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
    
    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
    
    private func beginSync() {
        syncStatus = .syncing
        appEnvironment?.isSyncing = true
    }
    
    private func endSync(success: Bool, error: Error? = nil, shouldUpdateTimestamp: Bool = true) {
        if success {
            if shouldUpdateTimestamp {
                lastSyncDate = Date()
            }
            syncStatus = .success
        } else if let error {
            syncStatus = .failed(error)
        } else {
            syncStatus = .idle
        }
        appEnvironment?.isSyncing = false
    }
    
    private func makeRecord<T: CloudSyncable>(from item: T) throws -> CKRecord {
        let recordID = CKRecord.ID(recordName: item.syncIdentifier)
        let record = CKRecord(recordType: T.recordType, recordID: recordID)
        let payload = try encoder.encode(item)
        record["payload"] = payload as NSData
        if let jsonString = String(data: payload, encoding: .utf8) {
            record["data"] = jsonString as CKRecordValue
        }
        record["updatedAt"] = Date() as NSDate
        return record
    }
    
    private func decodeRecord<T: CloudSyncable>(_ record: CKRecord, as type: T.Type) throws -> T {
        if let payload = record["payload"] as? Data {
            do {
                return try decoder.decode(T.self, from: payload)
            } catch {
                throw SyncServiceError.decodingFailed(error)
            }
        }
        if let jsonString = record["data"] as? String, let data = jsonString.data(using: .utf8) {
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw SyncServiceError.decodingFailed(error)
            }
        }
        throw SyncServiceError.missingPayload
    }
    
    func save<T: CloudSyncable>(_ item: T) async throws {
        beginSync()
        do {
            let record = try makeRecord(from: item)
            _ = try await privateDatabase.save(record)
            endSync(success: true)
        } catch {
            endSync(success: false, error: error)
            throw error
        }
    }
    
    func fetch<T: CloudSyncable>(_ id: T.ID, as type: T.Type = T.self) async throws -> T {
        beginSync()
        do {
            let recordID = CKRecord.ID(recordName: T.syncIdentifier(for: id))
            let record = try await privateDatabase.record(for: recordID)
            let item: T = try decodeRecord(record, as: T.self)
            endSync(success: true, shouldUpdateTimestamp: false)
            return item
        } catch {
            endSync(success: false, error: error, shouldUpdateTimestamp: false)
            throw error
        }
    }
    
    func fetchAll<T: CloudSyncable>(as type: T.Type = T.self) async throws -> [T] {
        beginSync()
        do {
            let query = CKQuery(recordType: T.recordType, predicate: NSPredicate(value: true))
            let (matchResults, _) = try await privateDatabase.records(matching: query)
            var items: [T] = []
            for result in matchResults.values {
                switch result {
                case .success(let record):
                    let item: T = try decodeRecord(record, as: T.self)
                    items.append(item)
                case .failure(let error):
                    throw error
                }
            }
            endSync(success: true, shouldUpdateTimestamp: false)
            return items
        } catch {
            endSync(success: false, error: error, shouldUpdateTimestamp: false)
            throw error
        }
    }
    
    func delete<T: CloudSyncable>(_ id: T.ID, as type: T.Type = T.self) async throws {
        beginSync()
        do {
            let recordID = CKRecord.ID(recordName: T.syncIdentifier(for: id))
            _ = try await privateDatabase.deleteRecord(withID: recordID)
            endSync(success: true)
        } catch {
            endSync(success: false, error: error)
            throw error
        }
    }
    
    func syncToCloud<T: Encodable>(data: T, recordType: String, recordID: String) async throws {
        beginSync()
        do {
            let recordID = CKRecord.ID(recordName: recordID)
            let record = CKRecord(recordType: recordType, recordID: recordID)
            let payload = try encoder.encode(data)
            record["payload"] = payload as NSData
            if let jsonString = String(data: payload, encoding: .utf8) {
                record["data"] = jsonString as CKRecordValue
            }
            record["updatedAt"] = Date() as NSDate
            _ = try await privateDatabase.save(record)
            endSync(success: true)
        } catch {
            endSync(success: false, error: error)
            throw error
        }
    }
    
    func fetchFromCloud(recordType: String, recordID: String) async throws -> CKRecord {
        beginSync()
        do {
            let recordID = CKRecord.ID(recordName: recordID)
            let record = try await privateDatabase.record(for: recordID)
            endSync(success: true, shouldUpdateTimestamp: false)
            return record
        } catch {
            endSync(success: false, error: error, shouldUpdateTimestamp: false)
            throw error
        }
    }
    
    func deleteFromCloud(recordType: String, recordID: String) async throws {
        beginSync()
        do {
            let recordID = CKRecord.ID(recordName: recordID)
            _ = try await privateDatabase.deleteRecord(withID: recordID)
            endSync(success: true)
        } catch {
            endSync(success: false, error: error)
            throw error
        }
    }
    
    func syncAllData() async throws {
        beginSync()
        endSync(success: true)
    }
    
    func syncAllData<T: CloudSyncable>(_ items: [T]) async throws {
        beginSync()
        do {
            for item in items {
                let record = try makeRecord(from: item)
                _ = try await privateDatabase.save(record)
            }
            endSync(success: true)
        } catch {
            endSync(success: false, error: error)
            throw error
        }
    }
    
    func shareRecord(_ record: CKRecord) async throws -> CKShare {
        beginSync()
        do {
            let share = CKShare(rootRecord: record)
            share[CKShare.SystemFieldKey.title] = "Shared Trip" as CKRecordValue
            _ = try await sharedDatabase.save(share)
            endSync(success: true)
            return share
        } catch {
            endSync(success: false, error: error)
            throw error
        }
    }
    
    func share<T: CloudSyncable>(_ item: T) async throws -> CKShare {
        beginSync()
        do {
            let record = try makeRecord(from: item)
            let share = CKShare(rootRecord: record)
            share[CKShare.SystemFieldKey.title] = T.recordType as CKRecordValue
            _ = try await sharedDatabase.save(share)
            endSync(success: true)
            return share
        } catch {
            endSync(success: false, error: error)
            throw error
        }
    }
}
