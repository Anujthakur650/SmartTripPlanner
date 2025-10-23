import Foundation
import Core

public protocol TripWeatherProviding {
    func currentConditions(for location: String) async throws -> String
}

public struct WeatherService: TripWeatherProviding {
    private let key: String

    public init(weatherKitKey: String) {
        self.key = weatherKitKey
    }

    public func currentConditions(for location: String) async throws -> String {
        // Placeholder implementation for bootstrap package targets.
        return "Sunny in \(location)"
    }
}

public struct ServiceRegistry {
    public let environment: AppEnvironment
    public let weatherService: TripWeatherProviding

    public init(environment: AppEnvironment = AppEnvironment(), weatherService: TripWeatherProviding) {
        self.environment = environment
        self.weatherService = weatherService
    }
}
