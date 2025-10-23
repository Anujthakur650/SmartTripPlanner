import Foundation

enum NormalizedWeatherCondition: String, Codable, CaseIterable {
    case clear
    case mostlyClear
    case partlyCloudy
    case cloudy
    case rain
    case heavyRain
    case thunderstorm
    case snow
    case sleet
    case windy
    case fog
    case hot
    case cold
    case tropicalStorm
    case dust
    case haze
    case smoke
    case unknown
}

struct WeatherReport: Codable, Equatable {
    struct DailySummary: Codable, Equatable, Identifiable {
        var date: Date
        var highTemperature: Double
        var lowTemperature: Double
        var precipitationChance: Double
        var condition: NormalizedWeatherCondition
        var sunrise: Date?
        var sunset: Date?
        
        var id: Date { date }
    }
    
    struct HourlySummary: Codable, Equatable, Identifiable {
        var date: Date
        var temperature: Double
        var precipitationChance: Double
        var condition: NormalizedWeatherCondition
        
        var id: Date { date }
    }
    
    enum Source: String, Codable {
        case live
        case cache
    }
    
    struct ProviderMetadata: Codable, Equatable {
        var attribution: String?
        var dataset: String?
    }
    
    let tripId: UUID
    let cacheKey: String
    let location: Coordinate
    let period: DateRange
    var timezoneIdentifier: String?
    var generatedAt: Date
    var source: Source
    var daily: [DailySummary]
    var hourly: [HourlySummary]
    var providerMetadata: ProviderMetadata?
    
    var averageHighTemperature: Double {
        guard !daily.isEmpty else { return 0 }
        return daily.map { $0.highTemperature }.reduce(0, +) / Double(daily.count)
    }
    
    var averageLowTemperature: Double {
        guard !daily.isEmpty else { return 0 }
        return daily.map { $0.lowTemperature }.reduce(0, +) / Double(daily.count)
    }
    
    var highestPrecipitationChance: Double {
        let dailyMax = daily.map { $0.precipitationChance }.max() ?? 0
        let hourlyMax = hourly.map { $0.precipitationChance }.max() ?? 0
        return max(dailyMax, hourlyMax)
    }
    
    var dominantCondition: NormalizedWeatherCondition {
        let combined = daily.map { $0.condition } + hourly.map { $0.condition }
        let counts = Dictionary(grouping: combined, by: { $0 }).mapValues { $0.count }
        return counts.sorted { $0.value > $1.value }.first?.key ?? .unknown
    }
    
    var isLikelyRainy: Bool {
        highestPrecipitationChance >= 0.4
    }
    
    var isLikelySnowy: Bool {
        daily.contains { $0.condition == .snow || $0.condition == .sleet }
    }
    
    var isHot: Bool {
        averageHighTemperature >= 27
    }
    
    var isCold: Bool {
        averageLowTemperature <= 5
    }
    
    func isExpired(ttl: TimeInterval, referenceDate: Date = Date()) -> Bool {
        referenceDate.timeIntervalSince(generatedAt) > ttl
    }
    
    func withSource(_ source: Source) -> WeatherReport {
        WeatherReport(tripId: tripId,
                      cacheKey: cacheKey,
                      location: location,
                      period: period,
                      timezoneIdentifier: timezoneIdentifier,
                      generatedAt: generatedAt,
                      source: source,
                      daily: daily,
                      hourly: hourly,
                      providerMetadata: providerMetadata)
    }
    
    func digest() -> WeatherDigest {
        WeatherDigest(averageHigh: averageHighTemperature,
                      averageLow: averageLowTemperature,
                      precipitationChance: highestPrecipitationChance,
                      dominantCondition: dominantCondition)
    }
}

struct WeatherDigest: Codable, Equatable {
    var averageHigh: Double
    var averageLow: Double
    var precipitationChance: Double
    var dominantCondition: NormalizedWeatherCondition
}

struct WeatherProviderResponse {
    var timezoneIdentifier: String?
    var daily: [WeatherReport.DailySummary]
    var hourly: [WeatherReport.HourlySummary]
    var metadata: WeatherReport.ProviderMetadata?
}

struct WeatherCacheKey: Hashable {
    let tripId: UUID
    let locationKey: String
    let period: DateRange
    
    var rawValue: String {
        let start = period.start.timeIntervalSince1970
        let end = period.end.timeIntervalSince1970
        return "\(tripId.uuidString)-\(locationKey)-\(Int(start))-\(Int(end))"
    }
    
    var fileName: String {
        rawValue + ".json"
    }
}
