import Foundation
import UniformTypeIdentifiers

enum DocumentKind: String, Codable, CaseIterable {
    case pdf
    case image
    case pass
    case unknown
    
    init(fileExtension: String) {
        let normalized = fileExtension.lowercased()
        switch normalized {
        case "pdf":
            self = .pdf
        case "jpg", "jpeg", "png", "heic", "tiff":
            self = .image
        case "pkpass":
            self = .pass
        default:
            self = .unknown
        }
    }
    
    init(contentType: UTType) {
        if contentType.conforms(to: .pdf) {
            self = .pdf
        } else if contentType.conforms(to: .image) {
            self = .image
        } else if let pkpass = UTType(filenameExtension: "pkpass"), contentType.conforms(to: pkpass) {
            self = .pass
        } else {
            self = .unknown
        }
    }
    
    var iconName: String {
        switch self {
        case .pdf:
            return "doc.richtext"
        case .image:
            return "photo.on.rectangle"
        case .pass:
            return "wallet.pass"
        case .unknown:
            return "doc"
        }
    }
    
    var localizedDescription: String {
        switch self {
        case .pdf:
            return "PDF"
        case .image:
            return "Image"
        case .pass:
            return "Pass"
        case .unknown:
            return "Document"
        }
    }
}

enum DocumentSource: String, Codable {
    case imported
    case scanned
}

struct DocumentMetadata: Codable, Equatable {
    var primaryDate: Date?
    var allDates: [Date]
    var confirmationCodes: [String]
    var summary: String?
    var rawTextSample: String?
    
    init(
        primaryDate: Date? = nil,
        allDates: [Date] = [],
        confirmationCodes: [String] = [],
        summary: String? = nil,
        rawTextSample: String? = nil
    ) {
        self.primaryDate = primaryDate
        self.allDates = allDates
        self.confirmationCodes = confirmationCodes
        self.summary = summary
        self.rawTextSample = rawTextSample
    }
    
    var hasMetadata: Bool {
        primaryDate != nil || !allDates.isEmpty || !confirmationCodes.isEmpty || !(summary ?? "").isEmpty
    }
}

struct DocumentAsset: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var tripName: String?
    var tripId: UUID?
    var fileName: String
    var kind: DocumentKind
    var createdAt: Date
    var updatedAt: Date
    var fileSize: Int64
    var tags: [String]
    var source: DocumentSource
    var metadata: DocumentMetadata
    
    init(
        id: UUID = UUID(),
        title: String,
        tripName: String? = nil,
        tripId: UUID? = nil,
        fileName: String,
        kind: DocumentKind,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        fileSize: Int64 = 0,
        tags: [String] = [],
        source: DocumentSource,
        metadata: DocumentMetadata = DocumentMetadata()
    ) {
        self.id = id
        self.title = title
        self.tripName = tripName
        self.tripId = tripId
        self.fileName = fileName
        self.kind = kind
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.fileSize = fileSize
        self.tags = tags
        self.source = source
        self.metadata = metadata
    }
    
    var displayTripName: String {
        tripName ?? "Unassigned"
    }
    
    var formattedSize: String {
        guard fileSize > 0 else { return "--" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
    
    var normalizedTags: [String] {
        tags.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .uniqued()
    }
    
    func matchesTrip(_ trip: String?) -> Bool {
        guard let trip else { return true }
        return displayTripName.caseInsensitiveCompare(trip) == .orderedSame
    }
    
    func matches(tagFilter: String?) -> Bool {
        guard let tagFilter else { return true }
        return normalizedTags.contains { $0.caseInsensitiveCompare(tagFilter) == .orderedSame }
    }
}

extension Array where Element: Hashable {
    fileprivate func uniqued() -> [Element] {
        var seen: Set<Element> = []
        return filter { seen.insert($0).inserted }
    }
}

#if DEBUG
extension DocumentAsset {
    static let sample = DocumentAsset(
        title: "Flight Confirmation",
        tripName: "Paris Getaway",
        fileName: "sample.pdf",
        kind: .pdf,
        createdAt: Date().addingTimeInterval(-86_400),
        updatedAt: Date().addingTimeInterval(-43_200),
        fileSize: 512_000,
        tags: ["Flight", "Check-in"],
        source: .imported,
        metadata: DocumentMetadata(
            primaryDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()),
            confirmationCodes: ["ABC123"],
            summary: "Flight from NYC to Paris with Air France"
        )
    )
}
#endif
