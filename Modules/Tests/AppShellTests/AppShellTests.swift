import XCTest
@testable import AppShell
import Services
import Core

final class AppShellTests: XCTestCase {
    func testRegistryUsesProvidedEnvironment() {
        let environment = AppEnvironment(isOnline: false)
        let registry = ServiceRegistry(environment: environment, weatherService: WeatherService(weatherKitKey: ""))
        XCTAssertFalse(registry.environment.isOnline)
    }
}
