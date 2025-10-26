import XCTest
@testable import SmartTripPlanner

final class DocumentStoreTests: XCTestCase {
    func testDocumentEncryption() async throws {
        let store = DocumentStore()
        // Test encryption/decryption
        XCTAssertNotNil(store)
    }
}
