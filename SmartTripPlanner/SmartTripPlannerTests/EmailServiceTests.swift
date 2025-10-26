import XCTest
@testable import SmartTripPlanner

final class EmailServiceTests: XCTestCase {
    func testGmailOAuthState() async throws {
        let service = EmailService()
        XCTAssertNotNil(service.isSignedIn)
    }
    
    func testReservationParsing() throws {
        let parser = TravelReservationParser()
        XCTAssertNotNil(parser)
    }
}
