import Foundation
import WeatherKit
import CoreLocation

protocol WeatherProviding {
    func forecast(for location: CLLocation, days: Int) async throws -> TripWeatherForecast
}

final class WeatherProvider: WeatherProviding {
    private let service: WeatherService
    private let calendar: Calendar
    
    init(service: WeatherService = WeatherService(), calendar: Calendar = .current) {
        self.service = service
        self.calendar = calendar
    }
    
    func forecast(for location: CLLocation, days: Int) async throws -> TripWeatherForecast {
        let weather = try await service.fetchWeather(for: location)
        let forecast = weather.dailyForecast.prefix(days)
        guard let today = forecast.first else {
            throw NSError(domain: "WeatherProvider", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing forecast data"])
        }
        let summary = TripWeatherSummary(condition: today.condition,
                                         temperature: weather.currentWeather.temperature,
                                         high: today.highTemperature,
                                         low: today.lowTemperature,
                                         precipitationChance: today.precipitationChance)
        let days = forecast.map { day -> TripWeatherDay in
            TripWeatherDay(date: day.date,
                           condition: day.condition,
                           high: day.highTemperature,
                           low: day.lowTemperature,
                           precipitationChance: day.precipitationChance,
                           symbolName: day.symbolName,
                           windSpeed: day.wind.speed)
        }
        return TripWeatherForecast(summary: summary, days: Array(days))
    }
}
