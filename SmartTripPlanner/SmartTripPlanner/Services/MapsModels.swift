import Foundation
import MapKit

struct Coordinate: Codable, Hashable {
    var latitude: CLLocationDegrees
    var longitude: CLLocationDegrees
    
    var locationCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    init(latitude: CLLocationDegrees, longitude: CLLocationDegrees) {
        self.latitude = latitude
        self.longitude = longitude
    }
    
    init(_ coordinate: CLLocationCoordinate2D) {
        self.init(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
}

struct PlaceAssociation: Codable, Hashable {
    var tripId: UUID?
    var tripName: String?
    var dayPlanDate: Date?
    
    var summary: String? {
        let tripComponent = tripName
        let dateComponent = dayPlanDate.map { $0.formatted(date: .abbreviated, time: .omitted) }
        switch (tripComponent, dateComponent) {
        case let (.some(trip), .some(date)):
            return "\(trip) – \(date)"
        case let (.some(trip), .none):
            return trip
        case let (.none, .some(date)):
            return date
        default:
            return nil
        }
    }
}

struct Place: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var subtitle: String
    var coordinate: Coordinate
    var locality: String?
    var administrativeArea: String?
    var country: String?
    var isoCountryCode: String?
    var category: String?
    var phoneNumber: String?
    var url: URL?
    var mapItemIdentifier: String?
    var isBookmarked: Bool
    var association: PlaceAssociation?
    var createdAt: Date
    
    init(id: UUID = UUID(),
         name: String,
         subtitle: String,
         coordinate: Coordinate,
         locality: String? = nil,
         administrativeArea: String? = nil,
         country: String? = nil,
         isoCountryCode: String? = nil,
         category: String? = nil,
         phoneNumber: String? = nil,
         url: URL? = nil,
         mapItemIdentifier: String? = nil,
         isBookmarked: Bool = false,
         association: PlaceAssociation? = nil,
         createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.coordinate = coordinate
        self.locality = locality
        self.administrativeArea = administrativeArea
        self.country = country
        self.isoCountryCode = isoCountryCode
        self.category = category
        self.phoneNumber = phoneNumber
        self.url = url
        self.mapItemIdentifier = mapItemIdentifier
        self.isBookmarked = isBookmarked
        self.association = association
        self.createdAt = createdAt
    }
    
    init(mapItem: MKMapItem, isBookmarked: Bool = false, association: PlaceAssociation? = nil) {
        let placemark = mapItem.placemark
        self.init(
            id: UUID(),
            name: mapItem.name ?? placemark.name ?? "Unknown",
            subtitle: placemark.title ?? "",
            coordinate: Coordinate(placemark.coordinate),
            locality: placemark.locality,
            administrativeArea: placemark.administrativeArea,
            country: placemark.country,
            isoCountryCode: placemark.isoCountryCode,
            category: mapItem.pointOfInterestCategory?.rawValue,
            phoneNumber: mapItem.phoneNumber,
            url: mapItem.url,
            mapItemIdentifier: mapItem.placemark.name,
            isBookmarked: isBookmarked,
            association: association
        )
    }
    
    var addressDescription: String {
        if !subtitle.isEmpty {
            return subtitle
        }
        let components = [locality, administrativeArea, country].compactMap { $0 }.filter { !$0.isEmpty }
        return components.joined(separator: ", ")
    }
    
    var coordinateKey: String {
        String(format: "%.5f-%.5f", coordinate.latitude, coordinate.longitude)
    }
    
    func makeMapItem() -> MKMapItem {
        let placemark = MKPlacemark(coordinate: coordinate.locationCoordinate)
        let item = MKMapItem(placemark: placemark)
        item.name = name
        item.phoneNumber = phoneNumber
        item.url = url
        return item
    }
}

struct RouteSnapshot: Codable, Hashable, Identifiable {
    let id: UUID
    let name: String
    let expectedTravelTime: TimeInterval
    let distance: CLLocationDistance
    let advisoryNotices: [String]
    
    init(id: UUID = UUID(), name: String, expectedTravelTime: TimeInterval, distance: CLLocationDistance, advisoryNotices: [String] = []) {
        self.id = id
        self.name = name
        self.expectedTravelTime = expectedTravelTime
        self.distance = distance
        self.advisoryNotices = advisoryNotices
    }
}

struct SavedRoute: Identifiable, Codable, Hashable {
    let id: UUID
    let from: Place
    let to: Place
    let mode: TransportMode
    let primary: RouteSnapshot
    let alternatives: [RouteSnapshot]
    let createdAt: Date
    
    init(id: UUID = UUID(), from: Place, to: Place, mode: TransportMode, primary: RouteSnapshot, alternatives: [RouteSnapshot], createdAt: Date = Date()) {
        self.id = id
        self.from = from
        self.to = to
        self.mode = mode
        self.primary = primary
        self.alternatives = alternatives
        self.createdAt = createdAt
    }
}

enum TransportMode: String, CaseIterable, Codable, Identifiable {
    case driving
    case walking
    case transit
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .driving: return "Driving"
        case .walking: return "Walking"
        case .transit: return "Transit"
        }
    }
    
    var systemImage: String {
        switch self {
        case .driving: return "car.fill"
        case .walking: return "figure.walk"
        case .transit: return "tram.fill"
        }
    }
    
    var mkTransportType: MKDirectionsTransportType {
        switch self {
        case .driving: return .automobile
        case .walking: return .walking
        case .transit: return .transit
        }
    }
    
    var appleMapsLaunchOption: String {
        switch self {
        case .driving: return MKLaunchOptionsDirectionsModeDriving
        case .walking: return MKLaunchOptionsDirectionsModeWalking
        case .transit: return MKLaunchOptionsDirectionsModeTransit
        }
    }
}

enum MapCategory: String, CaseIterable, Codable, Identifiable {
    case all
    case dining
    case lodging
    case attractions
    case transport
    case shopping
    case outdoor
    case services
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .all: return "All"
        case .dining: return "Food & Drink"
        case .lodging: return "Lodging"
        case .attractions: return "Attractions"
        case .transport: return "Transport"
        case .shopping: return "Shopping"
        case .outdoor: return "Outdoor"
        case .services: return "Services"
        }
    }
    
    var systemImage: String {
        switch self {
        case .all: return "sparkles"
        case .dining: return "fork.knife"
        case .lodging: return "bed.double.fill"
        case .attractions: return "star.fill"
        case .transport: return "bus.fill"
        case .shopping: return "bag.fill"
        case .outdoor: return "leaf.fill"
        case .services: return "wrench.fill"
        }
    }
    
    var pointOfInterestCategories: Set<MKPointOfInterestCategory> {
        switch self {
        case .all:
            return []
        case .dining:
            return [.restaurant, .cafe, .bakery]
        case .lodging:
            return [.hotel]
        case .attractions:
            return [.amusementPark, .museum, .theater, .touristInformation]
        case .transport:
            return [.airport, .busStation, .ferryTerminal, .trainStation]
        case .shopping:
            return [.store, .foodMarket]
        case .outdoor:
            return [.park, .marina, .campground, .nationalPark]
        case .services:
            return [.atm, .hospital, .pharmacy, .carRental]
        }
    }
}

struct MapSearchSuggestion: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let subtitle: String
    
    var formattedQuery: String {
        if subtitle.isEmpty {
            return title
        }
        return "\(title) \(subtitle)"
    }
}

@available(iOS 17.0, *)
enum OfflineRegionStatus: Hashable {
    case notDownloaded
    case queued
    case downloading(progress: Double)
    case available(updatedAt: Date?)
    case needsUpdate(updatedAt: Date?)
    case failed(message: String?)
    case cancelled
    
    var isActiveDownload: Bool {
        switch self {
        case .queued, .downloading:
            return true
        default:
            return false
        }
    }
    
    var isDownloaded: Bool {
        switch self {
        case .available, .needsUpdate:
            return true
        default:
            return false
        }
    }
}

@available(iOS 17.0, *)
struct OfflineStorageUsage: Equatable {
    var bytesUsed: Int64
    var bytesAvailable: Int64?
    
    static let zero = OfflineStorageUsage(bytesUsed: 0, bytesAvailable: nil)
}

@available(iOS 17.0, *)
struct OfflineRegionSuggestion: Identifiable, Hashable {
    let id: UUID
    var name: String
    var detail: String
    var boundingRegion: MKCoordinateRegion
    var estimatedBytes: Int64?
    var sourceDescription: String
    
    init(id: UUID = UUID(), name: String, detail: String, boundingRegion: MKCoordinateRegion, estimatedBytes: Int64? = nil, sourceDescription: String) {
        self.id = id
        self.name = name
        self.detail = detail
        self.boundingRegion = boundingRegion
        self.estimatedBytes = estimatedBytes
        self.sourceDescription = sourceDescription
    }
}

@available(iOS 17.0, *)
struct OfflineMapRegionState: Identifiable, Hashable {
    let id: UUID
    var mapIdentifier: UUID
    var name: String
    var subtitle: String
    var boundingRegion: MKCoordinateRegion
    var bytesOnDisk: Int64?
    var status: OfflineRegionStatus
    var lastUpdated: Date?
    var sourceDescription: String
    
    init(id: UUID = UUID(), mapIdentifier: UUID, name: String, subtitle: String, boundingRegion: MKCoordinateRegion, bytesOnDisk: Int64?, status: OfflineRegionStatus, lastUpdated: Date?, sourceDescription: String) {
        self.id = id
        self.mapIdentifier = mapIdentifier
        self.name = name
        self.subtitle = subtitle
        self.boundingRegion = boundingRegion
        self.bytesOnDisk = bytesOnDisk
        self.status = status
        self.lastUpdated = lastUpdated
        self.sourceDescription = sourceDescription
    }
}

@available(iOS 17.0, *)
struct OfflineDownloadSnapshot: Identifiable, Hashable {
    let id: UUID
    var name: String
    var detail: String
    var progress: Double
    var stateDescription: String
    var sourceDescription: String
    var canCancel: Bool
    
    init(id: UUID = UUID(), name: String, detail: String, progress: Double, stateDescription: String, sourceDescription: String, canCancel: Bool = true) {
        self.id = id
        self.name = name
        self.detail = detail
        self.progress = progress
        self.stateDescription = stateDescription
        self.sourceDescription = sourceDescription
        self.canCancel = canCancel
    }
}
