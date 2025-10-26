@testable import SmartTripPlanner
import XCTest

final class EmailServiceTests: XCTestCase {
    func testPerformFetchParsesFlightReservation() async throws {
        let mockClient = MockGmailClient()
        mockClient.messageIdentifiers = [GmailMessageIdentifier(id: "msg-1", threadId: "thread-1")]
        mockClient.messages = ["msg-1": sampleFlightMessage()]
        let service = EmailService(gmailClient: mockClient, parser: TravelReservationParser())
        let emails = try await service.performFetch(accessToken: "token", userEmail: "tester@example.com")
        XCTAssertEqual(emails.count, 1)
        let email = try XCTUnwrap(emails.first)
        XCTAssertEqual(email.subject, "Flight Confirmation AB123")
        XCTAssertEqual(email.reservations.count, 1)
        XCTAssertEqual(email.reservations.first?.kind, .flight)
        XCTAssertEqual(email.reservations.first?.confirmationCode, "AB123")
        XCTAssertEqual(service.messages.count, 1)
        XCTAssertEqual(service.userEmail, "tester@example.com")
    }
    
    func testPerformFetchHandlesRateLimit() async {
        let mockClient = MockGmailClient()
        mockClient.shouldRateLimit = true
        let service = EmailService(gmailClient: mockClient, parser: TravelReservationParser())
        do {
            _ = try await service.performFetch(accessToken: "token", userEmail: nil)
            XCTFail("Expected rate limit error")
        } catch let error as EmailService.ServiceError {
            switch error {
            case let .rateLimited(retryAfter):
                XCTAssertEqual(retryAfter, 120)
            default:
                XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testFetchEmailsRequiresSignIn() async {
        let service = EmailService(gmailClient: MockGmailClient(), parser: TravelReservationParser())
        do {
            _ = try await service.fetchEmails()
            XCTFail("Expected sign-in required error")
        } catch let error as EmailService.ServiceError {
            XCTAssertEqual(error, .signInRequired)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    // MARK: - Helpers
    
    private func sampleFlightMessage() -> GmailMessage {
        let headers = [
            GmailHeader(name: "Subject", value: "Flight Confirmation AB123"),
            GmailHeader(name: "From", value: "Example Air <no-reply@exampleair.com>")
        ]
        let bodyString = "Flight AB123 from SFO to JFK on 2024-11-01 departing 08:30"
        let bodyData = bodyString.data(using: .utf8)!
        let base64 = bodyData.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        let body = GmailBody(size: bodyData.count, data: base64)
        let payload = GmailPayload(partId: nil,
                                   mimeType: "text/plain",
                                   filename: "",
                                   headers: headers,
                                   body: body,
                                   parts: nil)
        return GmailMessage(id: "msg-1",
                            threadId: "thread-1",
                            labelIds: ["INBOX"],
                            snippet: bodyString,
                            payload: payload,
                            sizeEstimate: bodyData.count,
                            historyId: "1",
                            internalDate: "1700000000000")
    }
}

private final class MockGmailClient: GmailClient {
    var messageIdentifiers: [GmailMessageIdentifier] = []
    var messages: [String: GmailMessage] = [:]
    var shouldRateLimit = false
    
    func listMessageIdentifiers(accessToken: String, query: String?, maxResults: Int) async throws -> GmailMessageListResponse {
        if shouldRateLimit {
            throw GmailClientError.rateLimited(retryAfter: 120)
        }
        return GmailMessageListResponse(messages: messageIdentifiers, nextPageToken: nil)
    }
    
    func fetchMessage(accessToken: String, id: String) async throws -> GmailMessage {
        if shouldRateLimit {
            throw GmailClientError.rateLimited(retryAfter: 120)
        }
        guard let message = messages[id] else {
            throw GmailClientError.invalidResponse
        }
        return message
    }
}

extension EmailService.ServiceError: Equatable {
    public static func == (lhs: EmailService.ServiceError, rhs: EmailService.ServiceError) -> Bool {
        switch (lhs, rhs) {
        case (.missingRootViewController, .missingRootViewController),
             (.signInRequired, .signInRequired),
             (.missingAccessToken, .missingAccessToken):
            return true
        case let (.rateLimited(l), .rateLimited(r)):
            return Int(l) == Int(r)
        case let (.underlying(lhsError), .underlying(rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}
