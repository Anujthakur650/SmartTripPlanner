import Foundation
import CloudKit

@MainActor
class SyncService: ObservableObject {
    private let privateDatabase = CKContainer.default().privateCloudDatabase
    private let sharedDatabase = CKContainer.default().sharedCloudDatabase
    
    @Published var syncStatus: SyncStatus = .idle
    @Published var lastSyncDate: Date?
    
    enum SyncStatus {
        case idle
        case syncing
        case success
        case failed(Error)
    }
    
    func syncToCloud<T: Encodable>(data: T, recordType: String, recordID: String) async throws {
        syncStatus = .syncing
        
        do {
            let recordID = CKRecord.ID(recordName: recordID)
            let record = CKRecord(recordType: recordType, recordID: recordID)
            
            let encoder = JSONEncoder()
            let jsonData = try encoder.encode(data)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                record["data"] = jsonString as CKRecordValue
            }
            
            _ = try await privateDatabase.save(record)
            
            lastSyncDate = Date()
            syncStatus = .success
        } catch {
            syncStatus = .failed(error)
            throw error
        }
    }
    
    func fetchFromCloud(recordType: String, recordID: String) async throws -> CKRecord {
        let recordID = CKRecord.ID(recordName: recordID)
        return try await privateDatabase.record(for: recordID)
    }
    
    func deleteFromCloud(recordType: String, recordID: String) async throws {
        let recordID = CKRecord.ID(recordName: recordID)
        _ = try await privateDatabase.deleteRecord(withID: recordID)
    }
    
    func syncAllData() async throws {
        syncStatus = .syncing
        
        do {
            lastSyncDate = Date()
            syncStatus = .success
        } catch {
            syncStatus = .failed(error)
            throw error
        }
    }
    
    func shareRecord(_ record: CKRecord) async throws -> CKShare {
        let share = CKShare(rootRecord: record)
        share[CKShare.SystemFieldKey.title] = "Shared Trip" as CKRecordValue
        
        _ = try await sharedDatabase.save(share)
        return share
    }
}
