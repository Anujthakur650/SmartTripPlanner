import UIKit
import XCTest
@testable import SmartTripPlanner

final class SmartTripPlannerTests: XCTestCase {
    var container: DependencyContainer!
    var navigationCoordinator: NavigationCoordinator!
    var appEnvironment: AppEnvironment!
    
    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        container = DependencyContainer()
        navigationCoordinator = NavigationCoordinator()
        appEnvironment = AppEnvironment()
    }
    
    override func tearDown() async throws {
        container = nil
        navigationCoordinator = nil
        appEnvironment = nil
        try await super.tearDown()
    }
    
    @MainActor
    func testDependencyContainerInitialization() throws {
        XCTAssertNotNil(container.appEnvironment)
        XCTAssertNotNil(container.weatherService)
        XCTAssertNotNil(container.mapsService)
        XCTAssertNotNil(container.calendarService)
        XCTAssertNotNil(container.emailService)
        XCTAssertNotNil(container.exportService)
        XCTAssertNotNil(container.syncService)
    }
    
    @MainActor
    func testNavigationCoordinatorDefaultTab() throws {
        XCTAssertEqual(navigationCoordinator.selectedTab, .trips)
    }
    
    @MainActor
    func testNavigationCoordinatorTabSwitch() throws {
        navigationCoordinator.navigateTo(tab: .planner)
        XCTAssertEqual(navigationCoordinator.selectedTab, .planner)
        
        navigationCoordinator.navigateTo(tab: .settings)
        XCTAssertEqual(navigationCoordinator.selectedTab, .settings)
    }
    
    @MainActor
    func testAppEnvironmentTheme() throws {
        XCTAssertNotNil(appEnvironment.theme)
        XCTAssertTrue(appEnvironment.isOnline)
        XCTAssertFalse(appEnvironment.isSyncing)
    }
    
    @MainActor
    func testThemeColors() throws {
        let theme = Theme()
        XCTAssertNotNil(theme.primaryColor)
        XCTAssertNotNil(theme.secondaryColor)
        XCTAssertNotNil(theme.backgroundColor)
    }
    
    func testEmailParserParsesTravelSegmentsIncludingICS() throws {
        let body = """
        Flight: AA123
        From: Boston (BOS)
        To: Los Angeles (LAX)
        Departure: 2024-04-02T09:00:00Z
        Arrival: 2024-04-02T12:30:00Z
        
        Hotel: Downtown Suites
        Check-in: 2024-04-02
        Check-out: 2024-04-05
        Location: Los Angeles, CA
        """
        let bodyData = Data(body.utf8).base64URLEncodedString()
        let ics = """
        BEGIN:VCALENDAR
        BEGIN:VEVENT
        SUMMARY:Car Rental Pickup
        DTSTART:20240402T150000Z
        DTEND:20240409T150000Z
        LOCATION:Los Angeles Airport
        END:VEVENT
        END:VCALENDAR
        """
        let icsData = Data(ics.utf8).base64URLEncodedString()
        
        let payload = GmailPayload(
            partId: nil,
            mimeType: "multipart/mixed",
            filename: nil,
            headers: [GmailHeader(name: "Subject", value: "Flight to Los Angeles")],
            body: nil,
            parts: [
                GmailPayload(
                    partId: "0",
                    mimeType: "text/plain",
                    filename: nil,
                    headers: nil,
                    body: GmailBody(size: body.count, data: bodyData),
                    parts: nil
                ),
                GmailPayload(
                    partId: "1",
                    mimeType: "text/calendar",
                    filename: "event.ics",
                    headers: nil,
                    body: GmailBody(size: ics.count, data: icsData),
                    parts: nil
                )
            ]
        )
        let message = GmailMessage(
            id: "ABC123",
            threadId: "THREAD",
            labelIds: nil,
            snippet: nil,
            payload: payload,
            internalDate: nil
        )
        
        let parser = EmailParser()
        let candidate = parser.parse(message: message)
        XCTAssertNotNil(candidate)
        XCTAssertEqual(candidate?.segments.count, 3)
        let types = candidate?.segments.map(\.type)
        XCTAssertTrue(types?.contains(.flight) ?? false)
        XCTAssertTrue(types?.contains(.hotel) ?? false)
        XCTAssertTrue(types?.contains(.event) ?? false)
    }
    
    @MainActor
    func testEmailServiceStoresCredentialOnSignIn() async throws {
        let token = GmailToken(accessToken: "access", refreshToken: "refresh", expirationDate: Date().addingTimeInterval(3600))
        let credential = GmailCredential(email: "traveler@example.com", token: token)
        let authenticator = MockAuthenticator()
        authenticator.credential = credential
        let tokenStore = MockTokenStore()
        let apiClient = MockAPIClient()
        let service = EmailService(
            analyticsService: AnalyticsService(),
            authenticator: authenticator,
            tokenStore: tokenStore,
            apiClient: apiClient,
            parser: EmailParser(),
            deduplicator: MockDeduplicator(),
            dateProvider: { Date() },
            shouldAttemptRestore: false
        )
        
        try await service.signIn(presenting: UIViewController())
        XCTAssertTrue(service.isSignedIn)
        XCTAssertEqual(service.userEmail, credential.email)
        XCTAssertEqual(tokenStore.savedCredential, credential)
    }
}

// MARK: - Test Utilities

private extension Data {
    func base64URLEncodedString() -> String {
        let base64 = self.base64EncodedString()
        return base64
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

private final class MockAuthenticator: GmailAuthenticating {
    var credential: GmailCredential?
    var restoreCredential: GmailCredential?
    var refreshToken: GmailToken?
    
    func hasPreviousSignIn() -> Bool {
        restoreCredential != nil
    }
    
    func restorePreviousSignIn() async throws -> GmailCredential? {
        restoreCredential
    }
    
    func signIn(presenting viewController: UIViewController) async throws -> GmailCredential {
        guard let credential else { throw TestError.signInFailed }
        return credential
    }
    
    func refreshTokenIfNeeded(_ token: GmailToken) async throws -> GmailToken {
        refreshToken ?? token
    }
    
    func signOut() {}
}

private final class MockTokenStore: GmailTokenStore {
    var savedCredential: GmailCredential?
    
    func save(_ credential: GmailCredential) throws {
        savedCredential = credential
    }
    
    func loadCredential() throws -> GmailCredential? {
        savedCredential
    }
    
    func clear() throws {
        savedCredential = nil
    }
}

private final class MockAPIClient: GmailAPIClientProtocol {
    func listMessages(token: String, labelIds: [String], query: String, maxResults: Int) async throws -> [GmailMessageSummary] {
        []
    }
    
    func fetchMessage(id: String, token: String) async throws -> GmailMessage {
        throw TestError.unexpectedCall
    }
    
    func listLabels(token: String) async throws -> [GmailLabel] {
        []
    }
    
    func createLabel(named name: String, token: String) async throws -> GmailLabel {
        GmailLabel(id: "label", name: name)
    }
    
    func applyLabel(labelID: String, messageIDs: [String], token: String) async throws {}
}

private final class MockDeduplicator: EmailDeduplicating {
    func filterNewMessageIDs(_ ids: [String]) -> [String] { ids }
    func markProcessed(_ ids: [String]) {}
    func isProcessed(_ id: String) -> Bool { false }
    func reset() {}
}

private enum TestError: Error {
    case signInFailed
    case unexpectedCall
}
