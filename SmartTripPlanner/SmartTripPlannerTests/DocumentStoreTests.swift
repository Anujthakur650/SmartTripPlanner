import XCTest
@testable import SmartTripPlanner

final class DocumentStoreTests: XCTestCase {
    func testStoreInitialization() async throws {
        let store = DocumentStore()
        let docs = try await store.documents()
        XCTAssertNotNil(docs)
    }
}
