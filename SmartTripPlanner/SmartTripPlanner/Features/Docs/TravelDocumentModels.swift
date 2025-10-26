import Foundation
import SwiftUI

struct TravelDocument: Identifiable, Codable, Hashable {
    struct Metadata: Codable, Hashable {
        var title: String
        var type: DocumentType
        var notes: String
        var tags: [String]
        
        static func `default`(title: String, type: DocumentType = .other) -> Metadata {
            Metadata(title: title, type: type, notes: "", tags: [])
        }
    }
    
    enum DocumentType: String, CaseIterable, Codable, Identifiable {
        case passport
        case ticket
        case reservation
        case insurance
        case visa
        case vaccination
        case other
        
        var id: String { rawValue }
        
        var displayName: String {
            switch self {
            case .passport: return "Passport"
            case .ticket: return "Ticket"
            case .reservation: return "Reservation"
            case .insurance: return "Insurance"
            case .visa: return "Visa"
            case .vaccination: return "Vaccination"
            case .other: return "Other"
            }
        }
        
        var systemImage: String {
            switch self {
            case .passport: return "person.text.rectangle"
            case .ticket: return "ticket"
            case .reservation: return "calendar.badge.clock"
            case .insurance: return "shield.fill"
            case .visa: return "checkmark.seal"
            case .vaccination: return "bandage.fill"
            case .other: return "doc"
            }
        }
        
        var accentColor: Color {
            switch self {
            case .passport: return .blue
            case .ticket: return .orange
            case .reservation: return .purple
            case .insurance: return .teal
            case .visa: return .green
            case .vaccination: return .pink
            case .other: return .gray
            }
        }
    }
    
    let id: UUID
    var metadata: Metadata
    let fileName: String
    let createdAt: Date
    var updatedAt: Date
    let pageCount: Int
    let fileSize: Int
    let checksum: String
    
    var title: String { metadata.title }
    var type: DocumentType { metadata.type }
    var notes: String { metadata.notes }
    var tags: [String] { metadata.tags }
    
    init(id: UUID = UUID(), metadata: Metadata, fileName: String, createdAt: Date = Date(), updatedAt: Date = Date(), pageCount: Int, fileSize: Int, checksum: String) {
        self.id = id
        self.metadata = metadata
        self.fileName = fileName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.pageCount = pageCount
        self.fileSize = fileSize
        self.checksum = checksum
    }
    
    var formattedCreatedAt: String {
        createdAt.formatted(date: .abbreviated, time: .shortened)
    }
    
    var formattedUpdatedAt: String {
        updatedAt.formatted(date: .abbreviated, time: .shortened)
    }
}
