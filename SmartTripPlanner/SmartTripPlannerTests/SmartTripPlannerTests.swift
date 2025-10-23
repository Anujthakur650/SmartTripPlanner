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
        XCTAssertNotNil(container.tripStore)
        XCTAssertNotNil(container.packingService)
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
    
    @MainActor
    func testWeatherServiceUsesCacheWhenOffline() async throws {
        let environment = AppEnvironment()
        let mockProvider = MockWeatherProvider()
        let cacheURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let cacheStore = WeatherCacheStore(directory: cacheURL)
        let weatherService = WeatherService(appEnvironment: environment, provider: mockProvider, cacheStore: cacheStore, cacheTTL: 60 * 60)
        let startDate = Date()
        let endDate = startDate.addingTimeInterval(86400)
        let trip = Trip(
            name: "Weather Test",
            destination: "Test City",
            coordinate: Coordinate(latitude: 34.0, longitude: -118.0),
            startDate: startDate,
            endDate: endDate,
            tripType: .leisure
        )
        mockProvider.response = WeatherProviderResponse(
            timezoneIdentifier: "UTC",
            daily: [
                WeatherReport.DailySummary(
                    date: startDate,
                    highTemperature: 28,
                    lowTemperature: 18,
                    precipitationChance: 0.1,
                    condition: .clear,
                    sunrise: nil,
                    sunset: nil
                )
            ],
            hourly: [
                WeatherReport.HourlySummary(
                    date: startDate,
                    temperature: 26,
                    precipitationChance: 0.1,
                    condition: .clear
                )
            ],
            metadata: nil
        )
        let liveReport = try await weatherService.weatherReport(for: trip)
        XCTAssertEqual(mockProvider.fetchCallCount, 1)
        XCTAssertEqual(liveReport.source, .live)
        environment.isOnline = false
        let cachedReport = try await weatherService.weatherReport(for: trip)
        XCTAssertEqual(mockProvider.fetchCallCount, 1)
        XCTAssertEqual(cachedReport.source, .cache)
        XCTAssertEqual(cachedReport.cacheKey, liveReport.cacheKey)
        try? FileManager.default.removeItem(at: cacheURL)
    }
    
    func testPackingListGenerationDeterministic() throws {
        let startDate = Date()
        let endDate = startDate.addingTimeInterval(86400 * 4)
        let trip = Trip(
            name: "Beach Escape",
            destination: "Honolulu",
            coordinate: Coordinate(latitude: 21.3069, longitude: -157.8583),
            startDate: startDate,
            endDate: endDate,
            tripType: .beach,
            activities: [.swimming, .nightlife]
        )
        let weather = WeatherReport(
            tripId: trip.id,
            cacheKey: "test-cache",
            location: trip.coordinate!,
            period: trip.dateRange,
            timezoneIdentifier: "UTC",
            generatedAt: Date(),
            source: .live,
            daily: [
                WeatherReport.DailySummary(
                    date: startDate,
                    highTemperature: 31,
                    lowTemperature: 24,
                    precipitationChance: 0.1,
                    condition: .clear,
                    sunrise: nil,
                    sunset: nil
                )
            ],
            hourly: [
                WeatherReport.HourlySummary(
                    date: startDate,
                    temperature: 30,
                    precipitationChance: 0.05,
                    condition: .clear
                )
            ],
            providerMetadata: nil
        )
        let generator = PackingListGenerator()
        let context = PackingContext(trip: trip, weather: weather)
        let first = generator.generate(for: context)
        let second = generator.generate(for: context)
        XCTAssertEqual(first.map { $0.name }, second.map { $0.name })
        XCTAssertTrue(first.contains(where: { $0.name == "Swimsuit" }))
        XCTAssertTrue(first.contains(where: { $0.name == "Sunscreen" }))
    }
    
    func testPackingListPersistenceRoundTrip() throws {
        let trip = Trip(
            name: "Persistence Test",
            destination: "Berlin",
            coordinate: nil,
            startDate: Date(),
            endDate: Date().addingTimeInterval(86400 * 2),
            tripType: .business
        )
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = PackingListStore(directory: tempURL)
        var list = TripPackingList(tripId: trip.id)
        let item = PackingListItem(name: "Camera", category: .technology, quantity: 1, origin: .manual)
        list.addItem(item)
        try store.saveList(list)
        let loaded = store.loadList(for: trip.id)
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded, list)
        try? FileManager.default.removeItem(at: tempURL)
    }
}

private final class MockWeatherProvider: WeatherProvider {
    enum MockError: Error {
        case missingResponse
    }
    
    var response: WeatherProviderResponse?
    var error: Error?
    private(set) var fetchCallCount = 0
    
    func fetchWeather(for coordinate: Coordinate, period: DateRange) async throws -> WeatherProviderResponse {
        fetchCallCount += 1
        if let error {
            throw error
        }
        guard let response else {
            throw MockError.missingResponse
        }
        return response
    }
}
