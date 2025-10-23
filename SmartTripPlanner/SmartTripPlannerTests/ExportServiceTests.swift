import XCTest
import PDFKit
@testable import SmartTripPlanner

final class ExportServiceTests: XCTestCase {
    private var exportService: ExportService!
    private var dataStore: TravelDataStore!
    private var appEnvironment: AppEnvironment!
    private var mapsDataSource: MockMapsDataSource!
    
    @MainActor
    override func setUpWithError() throws {
        try super.setUpWithError()
        dataStore = TravelDataStore()
        appEnvironment = AppEnvironment()
        let origin = Place(
            name: "Union Square",
            subtitle: "San Francisco",
            coordinate: Coordinate(latitude: 37.7879, longitude: -122.4074)
        )
        let destination = Place(
            name: "Griffith Observatory",
            subtitle: "Los Angeles",
            coordinate: Coordinate(latitude: 34.1184, longitude: -118.3004)
        )
        let primary = RouteSnapshot(name: "Coastal Drive", expectedTravelTime: 21600, distance: 615000)
        let savedRoute = SavedRoute(from: origin, to: destination, mode: .driving, primary: primary, alternatives: [])
        mapsDataSource = MockMapsDataSource(savedRoutes: [savedRoute], savedPlaces: [origin, destination])
        exportService = ExportService(appEnvironment: appEnvironment, travelDataSource: dataStore, mapsDataSource: mapsDataSource)
    }
    
    @MainActor
    override func tearDownWithError() throws {
        exportService = nil
        dataStore = nil
        appEnvironment = nil
        mapsDataSource = nil
        try super.tearDownWithError()
    }
    
    @MainActor
    func testItineraryPDFGenerationContainsTripName() async throws {
        let record = try await exportService.exportCurrentItinerary(delivery: nil)
        let url = exportService.fileURL(for: record)
        guard let document = PDFDocument(url: url) else {
            XCTFail("Failed to open generated PDF")
            return
        }
        let pdfText = document.string ?? ""
        let tripName = dataStore.trips.first?.name ?? ""
        XCTAssertTrue(pdfText.contains(tripName), "PDF should contain the trip name")
        XCTAssertTrue(exportService.history.contains(record))
    }
    
    @MainActor
    func testGPXGenerationProducesValidXML() async throws {
        let record = try await exportService.exportGPX(delivery: nil)
        let data = try Data(contentsOf: exportService.fileURL(for: record))
        let parser = XMLParser(data: data)
        XCTAssertTrue(parser.parse(), "Generated GPX should be valid XML")
        let gpxString = String(data: data, encoding: .utf8) ?? ""
        XCTAssertTrue(gpxString.contains("<rtept"), "GPX should contain route points")
        XCTAssertTrue(gpxString.contains("<wpt"), "GPX should contain waypoints")
    }
    
    private final class MockMapsDataSource: MapsDataSource {
        var savedRoutes: [SavedRoute]
        var savedPlaces: [Place]
        
        init(savedRoutes: [SavedRoute], savedPlaces: [Place]) {
            self.savedRoutes = savedRoutes
            self.savedPlaces = savedPlaces
        }
    }
}
