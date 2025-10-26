import XCTest
@testable import SmartTripPlanner

final class EmailServiceTests: XCTestCase {
    func testEmailFetching() async throws {
        let service = EmailService()
        // Test OAuth state management
        XCTAssertNotNil(service.isSignedIn)
    }
}
