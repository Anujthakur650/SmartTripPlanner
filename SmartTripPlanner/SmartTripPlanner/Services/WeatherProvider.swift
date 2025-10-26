import Foundation
import WeatherKit
import CoreLocation

protocol WeatherDataProvider {
    func fetchWeather(for location: CLLocation, days: Int) async throws -> WeatherSummary
}

struct WeatherKitProvider: WeatherDataProvider {
    private let service: WeatherKit.WeatherService
    private let calendar: Calendar
    
    init(service: WeatherKit.WeatherService = WeatherKit.WeatherService(), calendar: Calendar = .current) {
        self.service = service
        self.calendar = calendar
    }
    
    func fetchWeather(for location: CLLocation, days: Int) async throws -> WeatherSummary {
        let weather = try await service.weather(for: location)
        let current = weather.currentWeather
        let dailyForecast = Array(weather.dailyForecast.forecast.prefix(days))
        let currentConditions = WeatherSummary.CurrentConditions(
            temperature: current.temperature,
            conditionDescription: current.condition.description,
            symbolName: current.symbolName,
            highTemperature: dailyForecast.first?.highTemperature ?? current.temperature,
            lowTemperature: dailyForecast.first?.lowTemperature ?? current.temperature,
            apparentTemperature: current.apparentTemperature,
            windSpeed: current.wind.speed,
            precipitationChance: current.precipitationChance,
            humidity: current.humidity
        )
        let forecast: [WeatherSummary.DailyForecast] = dailyForecast.map { day in
            WeatherSummary.DailyForecast(
                date: day.date,
                highTemperature: day.highTemperature,
                lowTemperature: day.lowTemperature,
                symbolName: day.symbolName,
                precipitationChance: day.precipitationChance
            )
        }
        return WeatherSummary(
            locationName: "",
            timezone: .current,
            asOf: weather.currentWeather.date,
            current: currentConditions,
            forecast: forecast
        )
    }
}
