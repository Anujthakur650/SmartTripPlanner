import Foundation
import WeatherKit

struct TripWeatherSummary: Equatable {
    var condition: WeatherCondition
    var temperature: Measurement<UnitTemperature>
    var high: Measurement<UnitTemperature>
    var low: Measurement<UnitTemperature>
    var precipitationChance: Double
}

struct TripWeatherDay: Identifiable, Equatable {
    var id: UUID
    var date: Date
    var condition: WeatherCondition
    var high: Measurement<UnitTemperature>
    var low: Measurement<UnitTemperature>
    var precipitationChance: Double
    var symbolName: String
    var windSpeed: Measurement<UnitSpeed>
    
    init(id: UUID = UUID(),
         date: Date,
         condition: WeatherCondition,
         high: Measurement<UnitTemperature>,
         low: Measurement<UnitTemperature>,
         precipitationChance: Double,
         symbolName: String,
         windSpeed: Measurement<UnitSpeed>) {
        self.id = id
        self.date = date
        self.condition = condition
        self.high = high
        self.low = low
        self.precipitationChance = precipitationChance
        self.symbolName = symbolName
        self.windSpeed = windSpeed
    }
}

struct TripWeatherForecast: Equatable {
    var summary: TripWeatherSummary
    var days: [TripWeatherDay]
}
