@testable import SmartTripPlanner
import XCTest

final class TripsRepositoryTests: XCTestCase {
    func testICSSampleImportProducesSegments() throws {
        let storage = TripsRepository.Storage.temporary(identifier: "ics-test")
        defer { try? FileManager.default.removeItem(at: storage.directory) }
        let repository = TripsRepository(storage: storage)
        let icsString = """
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Test Corp//Trip Planner//EN
X-WR-CALNAME:Test Adventure
BEGIN:VEVENT
UID:event-1
DTSTAMP:20240101T080000Z
DTSTART:20240501T090000Z
DTEND:20240501T120000Z
SUMMARY:Flight to Destination
LOCATION:Origin Airport
DESCRIPTION:Departing flight.
END:VEVENT
BEGIN:VEVENT
UID:event-2
DTSTART:20240502T140000Z
DTEND:20240502T170000Z
SUMMARY:City Walking Tour
LOCATION:Downtown Plaza
DESCRIPTION:Guided city tour.
END:VEVENT
END:VCALENDAR
"""
        let data = try XCTUnwrap(icsString.data(using: .utf8))
        let trip = try repository.importICS(data: data, reference: "sample.ics")
        XCTAssertEqual(trip.segments.count, 2)
        XCTAssertEqual(trip.destinations.count, 2)
        XCTAssertEqual(trip.source.kind, .ics)
        XCTAssertEqual(trip.source.reference, "sample.ics")
        XCTAssertEqual(trip.source.rawPayload?.contains("Flight to Destination"), true)
        XCTAssertTrue(repository.trips.contains(where: { $0.id == trip.id }))
    }
    
    func testCreatingTripPersistsToDisk() throws {
        let storage = TripsRepository.Storage.temporary(identifier: "persist-test")
        defer { try? FileManager.default.removeItem(at: storage.directory) }
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let repository = TripsRepository(storage: storage, now: { timestamp })
        let startDate = timestamp
        let endDate = timestamp.addingTimeInterval(86_400 * 4)
        let destination = TripDestination(name: "Paris", arrival: startDate, departure: endDate)
        let participant = TripParticipant(name: "Alex", contact: "alex@example.com")
        let segment = TripSegment(title: "Flight", location: "LAX", startDate: startDate, endDate: startDate.addingTimeInterval(14_400), segmentType: .transport, travelMode: .flight)
        _ = try repository.createTrip(
            name: "Spring Holiday",
            destinations: [destination],
            startDate: startDate,
            endDate: endDate,
            participants: [participant],
            preferredTravelModes: [.flight],
            segments: [segment],
            notes: "Pack light"
        )
        XCTAssertEqual(repository.trips.count, 1)
        let reloadedRepository = TripsRepository(storage: storage)
        XCTAssertEqual(reloadedRepository.trips.count, 1)
        XCTAssertEqual(reloadedRepository.trips.first?.name, "Spring Holiday")
        XCTAssertEqual(reloadedRepository.trips.first?.participants.first?.name, "Alex")
    }
}
