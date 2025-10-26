import Foundation

struct GPXMetadata: Equatable {
    var name: String
    var description: String?
    var author: String?
    var email: String?
    var keywords: [String]
    var creationDate: Date
    var link: URL?
    
    init(name: String, description: String? = nil, author: String? = nil, email: String? = nil, keywords: [String] = [], creationDate: Date = Date(), link: URL? = nil) {
        self.name = name
        self.description = description
        self.author = author
        self.email = email
        self.keywords = keywords
        self.creationDate = creationDate
        self.link = link
    }
}

struct GPXWaypoint: Equatable {
    var latitude: Double
    var longitude: Double
    var elevation: Double?
    var time: Date?
    var name: String?
    var comment: String?
    var symbol: String?
    var type: String?
    
    init(latitude: Double, longitude: Double, elevation: Double? = nil, time: Date? = nil, name: String? = nil, comment: String? = nil, symbol: String? = nil, type: String? = nil) {
        self.latitude = latitude
        self.longitude = longitude
        self.elevation = elevation
        self.time = time
        self.name = name
        self.comment = comment
        self.symbol = symbol
        self.type = type
    }
}

struct GPXTrackSegment: Equatable {
    var points: [GPXWaypoint]
    
    init(points: [GPXWaypoint]) {
        self.points = points
    }
}

struct GPXTrack: Equatable {
    var name: String
    var comment: String?
    var type: String?
    var segments: [GPXTrackSegment]
    
    init(name: String, comment: String? = nil, type: String? = nil, segments: [GPXTrackSegment]) {
        self.name = name
        self.comment = comment
        self.type = type
        self.segments = segments
    }
}
