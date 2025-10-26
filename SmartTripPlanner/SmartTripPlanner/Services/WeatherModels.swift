import Foundation

struct WeatherSummary: Equatable {
    struct CurrentConditions: Equatable {
        let temperature: Measurement<UnitTemperature>
        let conditionDescription: String
        let symbolName: String
        let highTemperature: Measurement<UnitTemperature>
        let lowTemperature: Measurement<UnitTemperature>
        let apparentTemperature: Measurement<UnitTemperature>
        let windSpeed: Measurement<UnitSpeed>?
        let precipitationChance: Double?
        let humidity: Double?
    }
    
    struct DailyForecast: Identifiable, Equatable {
        var id: Date { date }
        let date: Date
        let highTemperature: Measurement<UnitTemperature>
        let lowTemperature: Measurement<UnitTemperature>
        let symbolName: String
        let precipitationChance: Double
    }
    
    let locationName: String
    let timezone: TimeZone
    let asOf: Date
    let current: CurrentConditions
    let forecast: [DailyForecast]
    
    func withLocationName(_ name: String) -> WeatherSummary {
        WeatherSummary(locationName: name, timezone: timezone, asOf: asOf, current: current, forecast: forecast)
    }
}
