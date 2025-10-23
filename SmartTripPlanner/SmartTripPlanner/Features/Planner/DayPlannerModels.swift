import Foundation

enum TripType: String, CaseIterable, Codable, Equatable {
    case general
    case adventure
    case business
    case family
    case relaxation
    
    var displayName: String {
        switch self {
        case .general:
            return "General"
        case .adventure:
            return "Adventure"
        case .business:
            return "Business"
        case .family:
            return "Family"
        case .relaxation:
            return "Relaxation"
        }
    }
}

struct DayPlanItem: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var startDate: Date
    var duration: TimeInterval
    var location: String?
    var notes: String?
    var tags: [String]
    
    init(
        id: UUID = UUID(),
        title: String,
        startDate: Date,
        duration: TimeInterval,
        location: String? = nil,
        notes: String? = nil,
        tags: [String] = []
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.duration = duration
        self.location = location
        self.notes = notes
        self.tags = tags
    }
    
    var endDate: Date {
        startDate.addingTimeInterval(duration)
    }
}

struct DayPlan: Identifiable, Codable, Equatable {
    var date: Date
    var items: [DayPlanItem]
    
    var id: String {
        date.isoDayIdentifier
    }
    
    init(date: Date, items: [DayPlanItem] = []) {
        self.date = date.startOfDay()
        self.items = items.sorted(by: { $0.startDate < $1.startDate })
    }
    
    mutating func insert(_ item: DayPlanItem) {
        items.append(item)
        sortItems()
    }
    
    mutating func removeItem(withID id: UUID) -> DayPlanItem? {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return nil }
        return items.remove(at: index)
    }
    
    mutating func update(_ item: DayPlanItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index] = item
        sortItems()
    }
    
    mutating func sortItems() {
        items.sort(by: { $0.startDate < $1.startDate })
    }
}

struct PlannerState: Codable, Equatable {
    var days: [DayPlan]
    var activityLog: [ActivityLogEntry]
    
    static let empty = PlannerState(days: [], activityLog: [])
}

struct ActivityLogEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let timestamp: Date
    let description: String
    
    init(id: UUID = UUID(), timestamp: Date = Date(), description: String) {
        self.id = id
        self.timestamp = timestamp
        self.description = description
    }
}

struct QuickAddSuggestion: Identifiable, Equatable {
    let id: UUID
    let title: String
    let duration: TimeInterval
    let location: String?
    let notes: String?
    let tags: [String]
    
    init(
        id: UUID = UUID(),
        title: String,
        duration: TimeInterval,
        location: String? = nil,
        notes: String? = nil,
        tags: [String] = []
    ) {
        self.id = id
        self.title = title
        self.duration = duration
        self.location = location
        self.notes = notes
        self.tags = tags
    }
}

struct DayPlanDragPayload: Codable, Equatable {
    let itemID: UUID
    let sourceDayIdentifier: String
}

struct DropPreview: Equatable {
    let dayIdentifier: String
    let startDate: Date
}

struct DayPlanConflict: Equatable {
    enum ConflictType {
        case overlap
    }
    
    let type: ConflictType
    let message: String
}
