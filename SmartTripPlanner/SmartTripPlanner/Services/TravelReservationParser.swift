import Foundation

struct TravelReservation: Identifiable, Codable {
    enum ReservationType: String, Codable {
        case flight
        case hotel
    }
    
    let id: UUID
    let type: ReservationType
    var confirmationNumber: String?
    var provider: String?
    var originCode: String?
    var destinationCode: String?
    var startDate: Date?
    var endDate: Date?
    var locationName: String?
    
    init(id: UUID = UUID(),
         type: ReservationType,
         confirmationNumber: String? = nil,
         provider: String? = nil,
         originCode: String? = nil,
         destinationCode: String? = nil,
         startDate: Date? = nil,
         endDate: Date? = nil,
         locationName: String? = nil) {
        self.id = id
        self.type = type
        self.confirmationNumber = confirmationNumber
        self.provider = provider
        self.originCode = originCode
        self.destinationCode = destinationCode
        self.startDate = startDate
        self.endDate = endDate
        self.locationName = locationName
    }
}

struct TravelReservationParser {
    func parse(emailBody: String, subject: String) -> [TravelReservation]? {
        var reservations: [TravelReservation] = []
        
        if subject.lowercased().contains("flight") ||
            (emailBody.lowercased().contains("confirmation") && emailBody.lowercased().contains("airline")) {
            if let flight = extractFlightReservation(from: emailBody) {
                reservations.append(flight)
            }
        }
        
        if subject.lowercased().contains("hotel") || subject.lowercased().contains("booking") {
            if let hotel = extractHotelReservation(from: emailBody) {
                reservations.append(hotel)
            }
        }
        
        return reservations.isEmpty ? nil : reservations
    }
    
    private func extractFlightReservation(from body: String) -> TravelReservation? {
        let confirmation = firstMatch(for: "Confirmation[\\s:#]+([A-Z0-9]{3,})", in: body)
        let airline = firstMatch(for: "Airline[\\s:]+([A-Za-z\\s]+)", in: body)
        let departing = firstMatch(for: "Depart(?:ing|ure)[\\s:]+([A-Z]{3})", in: body)
        let arriving = firstMatch(for: "Arriv(?:ing|al)[\\s:]+([A-Z]{3})", in: body)
        let departureDateString = firstMatch(for: "(?:Departure|Departing) Date[\\s:]+([A-Za-z0-9,\\s:-]+)", in: body)
        let arrivalDateString = firstMatch(for: "(?:Arrival|Arriving) Date[\\s:]+([A-Za-z0-9,\\s:-]+)", in: body)
        
        let hasSignal = [confirmation, airline, departing, arriving, departureDateString].contains { $0 != nil }
        guard hasSignal else { return nil }
        
        let reservation = TravelReservation(
            type: .flight,
            confirmationNumber: confirmation,
            provider: airline,
            originCode: departing,
            destinationCode: arriving,
            startDate: parseDate(from: departureDateString),
            endDate: parseDate(from: arrivalDateString),
            locationName: arriving ?? departing
        )
        return reservation
    }
    
    private func extractHotelReservation(from body: String) -> TravelReservation? {
        let confirmation = firstMatch(for: "Confirmation[\\s:#]+([A-Z0-9]{3,})", in: body)
        let hotelName = firstMatch(for: "(?:Hotel|Property|Stay)[\\s:]+([A-Za-z0-9\\s]+)", in: body)
        let location = firstMatch(for: "Location[\\s:]+([A-Za-z0-9,\\s]+)", in: body) ?? hotelName
        let checkInString = firstMatch(for: "Check[-\\s]?In[\\s:]+([A-Za-z0-9,\\s/-]+)", in: body)
        let checkOutString = firstMatch(for: "Check[-\\s]?Out[\\s:]+([A-Za-z0-9,\\s/-]+)", in: body)
        
        let hasSignal = hotelName != nil || confirmation != nil || checkInString != nil
        guard hasSignal else { return nil }
        
        return TravelReservation(
            type: .hotel,
            confirmationNumber: confirmation,
            provider: hotelName,
            originCode: nil,
            destinationCode: nil,
            startDate: parseDate(from: checkInString),
            endDate: parseDate(from: checkOutString),
            locationName: location
        )
    }
    
    private func firstMatch(for pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range), match.numberOfRanges > 1 else { return nil }
        if let range = Range(match.range(at: 1), in: text) {
            return String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }
    
    private func parseDate(from string: String?) -> Date? {
        guard let string = string?.trimmingCharacters(in: .whitespacesAndNewlines), !string.isEmpty else { return nil }
        if let isoDate = TravelReservationParser.isoFormatter.date(from: string) {
            return isoDate
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        let patterns = [
            "MMM d, yyyy",
            "MMMM d, yyyy",
            "MM/dd/yyyy",
            "yyyy-MM-dd'T'HH:mm",
            "yyyy-MM-dd"
        ]
        for pattern in patterns {
            formatter.dateFormat = pattern
            if let date = formatter.date(from: string) {
                return date
            }
        }
        return nil
    }
    
    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        return formatter
    }()
}
