import Foundation

struct TravelReservationParser {
    private let calendar: Calendar
    
    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }
    
    func parse(subject: String, body: String, messageId: String, receivedDate: Date) -> [TravelReservation] {
        var reservations: [TravelReservation] = []
        let normalizedSubject = subject.lowercased()
        let normalizedBody = body.lowercased()
        
        if normalizedSubject.contains("flight") || normalizedBody.contains("flight") {
            if let reservation = parseFlight(subject: subject, body: body, messageId: messageId, receivedDate: receivedDate) {
                reservations.append(reservation)
            }
        }
        if normalizedSubject.contains("hotel") || normalizedBody.contains("hotel") || normalizedSubject.contains("stay") {
            if let reservation = parseHotel(subject: subject, body: body, messageId: messageId) {
                reservations.append(reservation)
            }
        }
        if normalizedSubject.contains("car") || normalizedBody.contains("rental") {
            if let reservation = parseCarRental(subject: subject, body: body, messageId: messageId) {
                reservations.append(reservation)
            }
        }
        return reservations
    }
    
    private func parseFlight(subject: String, body: String, messageId: String, receivedDate: Date) -> TravelReservation? {
        let numberRegex = try! NSRegularExpression(pattern: "([A-Z]{1,2}\\d{2,4})")
        let airportRegex = try! NSRegularExpression(pattern: "([A-Z]{3})\\s*(?:to|-|→|-)\\s*([A-Z]{3})", options: [.caseInsensitive])
        let dateRegex = try! NSRegularExpression(pattern: "(\n| )([0-9]{4}-[0-9]{2}-[0-9]{2})")
        let timeRegex = try! NSRegularExpression(pattern: "([01]?\\d|2[0-3]):([0-5]\\d)")
        let text = subject + "\n" + body
        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)
        var flightNumber: String?
        if let match = numberRegex.firstMatch(in: text, range: fullRange) {
            flightNumber = text.substring(with: match.range(at: 1))
        }
        var originCode: String?
        var destinationCode: String?
        if let match = airportRegex.firstMatch(in: text, range: fullRange) {
            originCode = text.substring(with: match.range(at: 1)).uppercased()
            destinationCode = text.substring(with: match.range(at: 2)).uppercased()
        }
        var departureDate = receivedDate
        if let match = dateRegex.firstMatch(in: text, range: fullRange) {
            let dateString = text.substring(with: match.range(at: 2))
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            if let date = formatter.date(from: dateString) {
                departureDate = date
            }
        }
        var departureTimeComponents: DateComponents?
        if let match = timeRegex.firstMatch(in: text, range: fullRange) {
            let hourString = text.substring(with: match.range(at: 1))
            let minuteString = text.substring(with: match.range(at: 2))
            if let hour = Int(hourString), let minute = Int(minuteString) {
                departureTimeComponents = DateComponents(hour: hour, minute: minute)
            }
        }
        var startDate: Date?
        if let components = departureTimeComponents {
            startDate = calendar.date(bySettingHour: components.hour ?? 0,
                                      minute: components.minute ?? 0,
                                      second: 0,
                                      of: departureDate)
        } else {
            startDate = departureDate
        }
        guard let flightNumber else { return nil }
        let origin = originCode.map { ReservationLocation(name: $0, code: $0) }
        let destination = destinationCode.map { ReservationLocation(name: $0, code: $0) }
        let title = "Flight \(flightNumber)"
        let reservation = TravelReservation(kind: .flight,
                                            title: title,
                                            provider: flightNumber.prefix(2).description,
                                            confirmationCode: flightNumber,
                                            travelers: [],
                                            startDate: startDate,
                                            endDate: nil,
                                            origin: origin,
                                            destination: destination,
                                            notes: body.replacingOccurrences(of: "\n\n", with: "\n"),
                                            rawEmailIdentifier: messageId)
        return reservation
    }
    
    private func parseHotel(subject: String, body: String, messageId: String) -> TravelReservation? {
        let pattern = "check-in\\s*:?\\s*([0-9]{4}-[0-9]{2}-[0-9]{2}).*check-out\\s*:?\\s*([0-9]{4}-[0-9]{2}-[0-9]{2})"
        let regex = try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators])
        let text = body
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        var checkInDate: Date?
        var checkOutDate: Date?
        if let match = regex.firstMatch(in: text, range: range) {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            if let checkIn = formatter.date(from: text.substring(with: match.range(at: 1))) {
                checkInDate = checkIn
            }
            if let checkOut = formatter.date(from: text.substring(with: match.range(at: 2))) {
                checkOutDate = checkOut
            }
        }
        let titleMatch = subject.components(separatedBy: " - ").last ?? subject
        let locationRegex = try! NSRegularExpression(pattern: "address\\s*:?\\s*(.*)", options: [.caseInsensitive])
        var address: String?
        if let match = locationRegex.firstMatch(in: text, range: range) {
            address = text.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let location = ReservationLocation(name: titleMatch, address: address)
        return TravelReservation(kind: .hotel,
                                 title: titleMatch,
                                 provider: titleMatch,
                                 confirmationCode: extractConfirmationCode(from: subject, body: body),
                                 travelers: [],
                                 startDate: checkInDate,
                                 endDate: checkOutDate,
                                 origin: location,
                                 destination: nil,
                                 notes: body,
                                 rawEmailIdentifier: messageId)
    }
    
    private func parseCarRental(subject: String, body: String, messageId: String) -> TravelReservation? {
        let pickupRegex = try! NSRegularExpression(pattern: "pickup(?: location)?\\s*:?\\s*(.*)", options: [.caseInsensitive])
        let dropoffRegex = try! NSRegularExpression(pattern: "drop(?:-?off)?\\s*:?\\s*(.*)", options: [.caseInsensitive])
        let timeRegex = try! NSRegularExpression(pattern: "(\b\d{4}-\d{2}-\d{2}\b)(?:.*?)(\b\d{2}:\d{2}\b)", options: [.caseInsensitive | .dotMatchesLineSeparators])
        let text = body
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        var pickupLocation: ReservationLocation?
        if let match = pickupRegex.firstMatch(in: text, range: range) {
            let value = text.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
            pickupLocation = ReservationLocation(name: value)
        }
        var dropoffLocation: ReservationLocation?
        if let match = dropoffRegex.firstMatch(in: text, range: range) {
            let value = text.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
            dropoffLocation = ReservationLocation(name: value)
        }
        var pickupDate: Date?
        var dropoffDate: Date?
        let matches = timeRegex.matches(in: text, range: range)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        if matches.count >= 1 {
            let dateString = text.substring(with: matches[0].range(at: 1))
            let timeString = text.substring(with: matches[0].range(at: 2))
            pickupDate = formatter.date(from: "\(dateString) \(timeString)")
        }
        if matches.count >= 2 {
            let dateString = text.substring(with: matches[1].range(at: 1))
            let timeString = text.substring(with: matches[1].range(at: 2))
            dropoffDate = formatter.date(from: "\(dateString) \(timeString)")
        }
        let title = subject.components(separatedBy: " - ").first ?? "Car Rental"
        return TravelReservation(kind: .carRental,
                                 title: title,
                                 provider: title,
                                 confirmationCode: extractConfirmationCode(from: subject, body: body),
                                 travelers: [],
                                 startDate: pickupDate,
                                 endDate: dropoffDate,
                                 origin: pickupLocation,
                                 destination: dropoffLocation,
                                 notes: body,
                                 rawEmailIdentifier: messageId)
    }
    
    private func extractConfirmationCode(from subject: String, body: String) -> String? {
        let regex = try! NSRegularExpression(pattern: "confirm(?:ation)?\\s*(?:code)?\\s*[:#-]?\\s*([A-Z0-9]{4,})", options: [.caseInsensitive])
        let combined = subject + "\n" + body
        let range = NSRange(combined.startIndex..<combined.endIndex, in: combined)
        if let match = regex.firstMatch(in: combined, range: range) {
            return combined.substring(with: match.range(at: 1))
        }
        return nil
    }
}

private extension String {
    func substring(with range: NSRange) -> String {
        guard let r = Range(range, in: self) else { return "" }
        return String(self[r])
    }
}
