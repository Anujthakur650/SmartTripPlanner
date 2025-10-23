import Foundation
import WeatherKit
import CoreLocation

@MainActor
class WeatherService: ObservableObject {
    private let weatherService = WeatherKit.WeatherService()
    
    func fetchWeather(for location: CLLocation) async throws -> Weather {
        return try await weatherService.weather(for: location)
    }
    
    func fetchForecast(for location: CLLocation, days: Int = 7) async throws -> Forecast<DayWeather> {
        let weather = try await weatherService.weather(for: location)
        return weather.dailyForecast
    }
}
