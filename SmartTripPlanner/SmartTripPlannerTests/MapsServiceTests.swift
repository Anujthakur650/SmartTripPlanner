import XCTest
@testable import SmartTripPlanner

final class MapsServiceTests: XCTestCase {
    func testLocationSearch() async throws {
        let service = MapsService(analyticsService: AnalyticsService())
        XCTAssertNotNil(service)
    }
}
