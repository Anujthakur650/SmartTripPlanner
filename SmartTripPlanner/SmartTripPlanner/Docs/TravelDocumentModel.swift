import Foundation

enum TravelDocumentType: String, Codable, CaseIterable, Identifiable {
    case passport
    case visa
    case ticket
    case reservation
    case insurance
    case id
    case covidCertificate
    case other
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .passport: return "Passport"
        case .visa: return "Visa"
        case .ticket: return "Ticket"
        case .reservation: return "Reservation"
        case .insurance: return "Insurance"
        case .id: return "Identification"
        case .covidCertificate: return "Health Certificate"
        case .other: return "Other"
        }
    }
    
    var systemImage: String {
        switch self {
        case .passport: return "person.text.rectangle"
        case .visa: return "globe"
        case .ticket: return "airplane"
        case .reservation: return "calendar.badge.clock"
        case .insurance: return "shield.fill"
        case .id: return "doc.text"
        case .covidCertificate: return "cross.fill"
        case .other: return "doc"
        }
    }
}

struct TravelDocumentMetadata: Codable, Equatable {
    var title: String
    var type: TravelDocumentType
    var tags: [String]
    var notes: String?
    var tripId: UUID?
    var tripName: String?
    var referenceNumber: String?
    var validFrom: Date?
    var validTo: Date?
    var lastViewedAt: Date?
    
    init(title: String,
         type: TravelDocumentType,
         tags: [String] = [],
         notes: String? = nil,
         tripId: UUID? = nil,
         tripName: String? = nil,
         referenceNumber: String? = nil,
         validFrom: Date? = nil,
         validTo: Date? = nil,
         lastViewedAt: Date? = nil) {
        self.title = title
        self.type = type
        self.tags = tags
        self.notes = notes
        self.tripId = tripId
        self.tripName = tripName
        self.referenceNumber = referenceNumber
        self.validFrom = validFrom
        self.validTo = validTo
        self.lastViewedAt = lastViewedAt
    }
}

struct TravelDocument: Identifiable, Codable, Equatable {
    var id: UUID
    var filename: String
    var metadata: TravelDocumentMetadata
    var createdAt: Date
    var updatedAt: Date
    var fileSize: Int64
    
    init(id: UUID = UUID(),
         filename: String,
         metadata: TravelDocumentMetadata,
         createdAt: Date = Date(),
         updatedAt: Date = Date(),
         fileSize: Int64 = 0) {
        self.id = id
        self.filename = filename
        self.metadata = metadata
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.fileSize = fileSize
    }
    
    var fileExtension: String {
        (filename as NSString).pathExtension
    }
}
