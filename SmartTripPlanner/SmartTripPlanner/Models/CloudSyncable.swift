import Foundation
import CloudKit

protocol CloudSyncable: Identifiable, Codable, Sendable {
    static var recordType: CKRecord.RecordType { get }
    var syncIdentifier: String { get }
    static func syncIdentifier(for id: ID) -> String
}

extension CloudSyncable where ID == UUID {
    var syncIdentifier: String { id.uuidString }
    static func syncIdentifier(for id: UUID) -> String { id.uuidString }
}

extension CloudSyncable where ID == String {
    var syncIdentifier: String { id }
    static func syncIdentifier(for id: String) -> String { id }
}
