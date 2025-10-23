import Foundation

struct Trip: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var destination: String
    var startDate: Date
    var endDate: Date
    var travelers: [String]
    var notes: String?
    
    init(id: UUID = UUID(),
         name: String,
         destination: String,
         startDate: Date,
         endDate: Date,
         travelers: [String] = [],
         notes: String? = nil) {
        self.id = id
        self.name = name
        self.destination = destination
        self.startDate = startDate
        self.endDate = endDate
        self.travelers = travelers
        self.notes = notes
    }
    
    var durationInDays: Int {
        Calendar.current.dateComponents([.day], from: startDate.startOfDay, to: endDate.startOfDay).day.map { $0 + 1 } ?? 0
    }
}

struct TripSegment: Identifiable, Codable, Equatable {
    enum Mode: String, Codable, CaseIterable {
        case flight
        case train
        case drive
        case ferry
        case transit
        case walk
        case other
        
        var localizedTitle: String {
            switch self {
            case .flight:
                return String(localized: "Flight")
            case .train:
                return String(localized: "Train")
            case .drive:
                return String(localized: "Drive")
            case .ferry:
                return String(localized: "Ferry")
            case .transit:
                return String(localized: "Transit")
            case .walk:
                return String(localized: "Walk")
            case .other:
                return String(localized: "Other")
            }
        }
    }
    
    struct Event: Codable, Equatable {
        var date: Date
        var location: String
        var notes: String?
        
        init(date: Date, location: String, notes: String? = nil) {
            self.date = date
            self.location = location
            self.notes = notes
        }
    }
    
    let id: UUID
    var title: String
    var subtitle: String
    var mode: Mode
    var departure: Event
    var arrival: Event
    var notes: String?
    
    init(id: UUID = UUID(),
         title: String,
         subtitle: String,
         mode: Mode,
         departure: Event,
         arrival: Event,
         notes: String? = nil) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.mode = mode
        self.departure = departure
        self.arrival = arrival
        self.notes = notes
    }
}

struct DayPlan: Identifiable, Codable, Equatable {
    let id: UUID
    var date: Date
    var title: String
    var items: [DayPlanItem]
    
    init(id: UUID = UUID(), date: Date, title: String, items: [DayPlanItem] = []) {
        self.id = id
        self.date = date
        self.title = title
        self.items = items
    }
}

struct DayPlanItem: Identifiable, Codable, Equatable {
    let id: UUID
    var time: DateComponents?
    var title: String
    var details: String
    var location: String?
    
    init(id: UUID = UUID(), time: DateComponents? = nil, title: String, details: String, location: String? = nil) {
        self.id = id
        self.time = time
        self.title = title
        self.details = details
        self.location = location
    }
}

struct PackingItem: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var isChecked: Bool
    var category: String?
    
    init(id: UUID = UUID(), name: String, isChecked: Bool = false, category: String? = nil) {
        self.id = id
        self.name = name
        self.isChecked = isChecked
        self.category = category
    }
}

struct TravelDocument: Identifiable, Codable, Equatable {
    enum DocumentType: String, Codable, CaseIterable {
        case passport
        case ticket
        case reservation
        case insurance
        case other
        
        var localizedTitle: String {
            switch self {
            case .passport:
                return String(localized: "Passport")
            case .ticket:
                return String(localized: "Ticket")
            case .reservation:
                return String(localized: "Reservation")
            case .insurance:
                return String(localized: "Insurance")
            case .other:
                return String(localized: "Other")
            }
        }
        
        var systemImage: String {
            switch self {
            case .passport:
                return "person.text.rectangle"
            case .ticket:
                return "ticket"
            case .reservation:
                return "calendar.badge.clock"
            case .insurance:
                return "shield.fill"
            case .other:
                return "doc"
            }
        }
    }
    
    let id: UUID
    var name: String
    var type: DocumentType
    var notes: String?
    
    init(id: UUID = UUID(), name: String, type: DocumentType, notes: String? = nil) {
        self.id = id
        self.name = name
        self.type = type
        self.notes = notes
    }
}

private extension Date {
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }
}
