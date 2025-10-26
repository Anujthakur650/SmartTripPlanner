@testable import SmartTripPlanner
import XCTest

final class ExportServiceTests: XCTestCase {
    private var exportService: ExportService!
    private let fileManager = FileManager.default
    
    override func setUp() {
        super.setUp()
        exportService = ExportService()
    }
    
    override func tearDown() {
        super.tearDown()
        cleanupTemporaryFiles()
        exportService = nil
    }
    
    func testExportToGPXIncludesTripMetadataAndWaypoints() async throws {
        let trip = sampleTrip()
        let url = try await exportService.exportToGPX(for: trip, description: "Summer vacation")
        let data = try Data(contentsOf: url)
        let gpxString = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(gpxString.contains("<gpx"))
        XCTAssertTrue(gpxString.contains("Summer vacation"))
        XCTAssertTrue(gpxString.contains("Flight AB123 - Origin"))
        XCTAssertTrue(gpxString.contains("lat=\"37.6213"))
        XCTAssertTrue(gpxString.contains("lon=\"-122.379"))
    }
    
    func testExportToJSONCreatesFile() async throws {
        struct Sample: Codable, Equatable { let name: String; let value: Int }
        let sample = Sample(name: "Test", value: 42)
        let url = try await exportService.exportToJSON(data: sample, filename: "Sample")
        XCTAssertTrue(fileManager.fileExists(atPath: url.path))
        let savedData = try Data(contentsOf: url)
        let decoded = try JSONDecoder().decode(Sample.self, from: savedData)
        XCTAssertEqual(decoded, sample)
    }
    
    func testSanitizedFilenameRemovesInvalidCharacters() async throws {
        let trip = Trip(name: "Trip:/\\*?", destination: "NYC", startDate: Date(), endDate: Date().addingTimeInterval(86400))
        let url = try await exportService.exportToGPX(for: trip)
        XCTAssertFalse(url.lastPathComponent.contains("/"))
        XCTAssertTrue(url.lastPathComponent.hasSuffix(".gpx"))
    }
    
    // MARK: - Helpers
    
    private func sampleTrip() -> Trip {
        let startDate = ISO8601DateFormatter().date(from: "2024-11-01T08:30:00Z")!
        let endDate = ISO8601DateFormatter().date(from: "2024-11-10T17:45:00Z")!
        let origin = ReservationLocation(name: "San Francisco International", address: "San Francisco, CA", coordinate: Coordinate(latitude: 37.6213, longitude: -122.3790), code: "SFO")
        let destination = ReservationLocation(name: "John F. Kennedy International", address: "New York, NY", coordinate: Coordinate(latitude: 40.6413, longitude: -73.7781), code: "JFK")
        let reservation = TravelReservation(kind: .flight,
                                            title: "Flight AB123",
                                            provider: "Example Air",
                                            confirmationCode: "AB123",
                                            travelers: ["Test Traveler"],
                                            startDate: startDate,
                                            endDate: endDate,
                                            origin: origin,
                                            destination: destination,
                                            notes: "Seat 12A",
                                            rawEmailIdentifier: "msg-1")
        let itineraryItem = ItineraryItem(title: "Arrive in NYC",
                                          detail: "Check-in at hotel",
                                          type: .activity,
                                          reservation: reservation,
                                          startDate: endDate,
                                          location: ReservationLocation(name: "Hotel", address: "Manhattan", coordinate: Coordinate(latitude: 40.7580, longitude: -73.9855)))
        return Trip(name: "Summer Adventure",
                    destination: "New York",
                    startDate: startDate,
                    endDate: endDate,
                    description: "Summer vacation",
                    reservations: [reservation],
                    itineraryItems: [itineraryItem])
    }
    
    private func cleanupTemporaryFiles() {
        let tempDir = fileManager.temporaryDirectory
        do {
            let contents = try fileManager.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
            for item in contents where item.lastPathComponent.contains("Summer") || item.lastPathComponent.contains("Trip") || item.lastPathComponent.contains("Sample") {
                try? fileManager.removeItem(at: item)
            }
        } catch {
            // Ignore cleanup errors in tests
        }
    }
}
