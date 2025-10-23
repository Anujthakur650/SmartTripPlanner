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
}
