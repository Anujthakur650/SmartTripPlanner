import Foundation

enum TripType: String, CaseIterable, Codable, Identifiable {
    case leisure
    case business
    case adventure
    case beach
    case ski
    case family
    case backpacking
    case cruise
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .leisure: return "Leisure"
        case .business: return "Business"
        case .adventure: return "Adventure"
        case .beach: return "Beach"
        case .ski: return "Ski"
        case .family: return "Family"
        case .backpacking: return "Backpacking"
        case .cruise: return "Cruise"
        }
    }
}

enum TripActivity: String, CaseIterable, Codable, Identifiable, Hashable {
    case hiking
    case swimming
    case skiing
    case sightseeing
    case nightlife
    case photography
    case foodTour
    case conference
    case shopping
    case kidsActivities
    case wellness
    case cycling
    case watersports
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .hiking: return "Hiking"
        case .swimming: return "Swimming"
        case .skiing: return "Skiing"
        case .sightseeing: return "Sightseeing"
        case .nightlife: return "Nightlife"
        case .photography: return "Photography"
        case .foodTour: return "Food Tour"
        case .conference: return "Conference"
        case .shopping: return "Shopping"
        case .kidsActivities: return "Family"
        case .wellness: return "Wellness"
        case .cycling: return "Cycling"
        case .watersports: return "Water Sports"
        }
    }
}

struct Trip: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var destination: String
    var coordinate: Coordinate?
    var startDate: Date
    var endDate: Date
    var tripType: TripType
    var activities: Set<TripActivity>
    var notes: String?
    var createdAt: Date
    var updatedAt: Date
    
    init(id: UUID = UUID(),
         name: String,
         destination: String,
         coordinate: Coordinate? = nil,
         startDate: Date,
         endDate: Date,
         tripType: TripType = .leisure,
         activities: Set<TripActivity> = [],
         notes: String? = nil,
         createdAt: Date = Date(),
         updatedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.destination = destination
        self.coordinate = coordinate
        self.startDate = startDate
        self.endDate = endDate
        self.tripType = tripType
        self.activities = activities
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    var dateRange: DateRange {
        DateRange(start: startDate, end: endDate)
    }
    
    var durationInDays: Int {
        dateRange.numberOfDays
    }
    
    var locationKey: String? {
        coordinate?.coordinateKey
    }
    
    var displayDestination: String {
        if let coordinate {
            return "\(destination) (\(coordinate.latitude.roundedDigits(places: 2)), \(coordinate.longitude.roundedDigits(places: 2)))"
        }
        return destination
    }
    
    func updatingDates(start: Date, end: Date) -> Trip {
        Trip(id: id,
             name: name,
             destination: destination,
             coordinate: coordinate,
             startDate: start,
             endDate: end,
             tripType: tripType,
             activities: activities,
             notes: notes,
             createdAt: createdAt,
             updatedAt: Date())
    }
}

extension Trip {
    static var sampleTrips: [Trip] {
        let calendar = Calendar.current
        let now = calendar.startOfDay(for: Date())
        let oneWeek = calendar.date(byAdding: .day, value: 7, to: now) ?? now.addingTimeInterval(604_800)
        let skiEnd = calendar.date(byAdding: .day, value: 5, to: now) ?? now.addingTimeInterval(432_000)
        return [
            Trip(
                name: "Barcelona Getaway",
                destination: "Barcelona, Spain",
                coordinate: Coordinate(latitude: 41.3851, longitude: 2.1734),
                startDate: now,
                endDate: oneWeek,
                tripType: .leisure,
                activities: [.sightseeing, .nightlife, .foodTour]
            ),
            Trip(
                name: "Aspen Ski Retreat",
                destination: "Aspen, USA",
                coordinate: Coordinate(latitude: 39.1911, longitude: -106.8175),
                startDate: now,
                endDate: skiEnd,
                tripType: .ski,
                activities: [.skiing, .wellness]
            ),
        ]
    }
}

private extension Double {
    func roundedDigits(places: Int) -> Double {
        let multiplier = pow(10.0, Double(places))
        return (self * multiplier).rounded() / multiplier
    }
}
