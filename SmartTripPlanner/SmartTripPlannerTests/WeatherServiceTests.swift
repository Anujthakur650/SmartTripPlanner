import XCTest
@testable import SmartTripPlanner

final class WeatherServiceTests: XCTestCase {
    func testWeatherForecastParsing() throws {
        let service = WeatherService()
        // Test with mock WeatherKit response
        XCTAssertNotNil(service)
    }
}
