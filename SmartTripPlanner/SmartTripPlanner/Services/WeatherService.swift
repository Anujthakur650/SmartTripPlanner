import Foundation
import WeatherKit
import CoreLocation

@MainActor
final class WeatherService: ObservableObject {
    enum WeatherServiceError: LocalizedError {
        case missingCoordinate
        case offlineDataUnavailable
        case cacheUnavailable
        
        var errorDescription: String? {
            switch self {
            case .missingCoordinate:
                return "Trip does not have a coordinate to fetch weather for."
            case .offlineDataUnavailable:
                return "You're offline and no cached weather is available."
            case .cacheUnavailable:
                return "No cached weather data is available."
            }
        }
    }
    
    private let provider: WeatherProvider
    private let cacheStore: WeatherCacheStore
    private unowned let appEnvironment: AppEnvironment
    private let cacheTTL: TimeInterval
    private var inMemoryCache: [String: WeatherReport] = [:]
    
    init(appEnvironment: AppEnvironment,
         provider: WeatherProvider? = nil,
         cacheStore: WeatherCacheStore = WeatherCacheStore(),
         cacheTTL: TimeInterval = 60 * 60 * 3) {
        self.appEnvironment = appEnvironment
        self.cacheStore = cacheStore
        self.cacheTTL = cacheTTL
        if let provider {
            self.provider = provider
        } else {
            self.provider = WeatherKitWeatherProvider()
        }
    }
    
    func weatherReport(for trip: Trip, forceRefresh: Bool = false) async throws -> WeatherReport {
        guard let coordinate = trip.coordinate, let locationKey = trip.locationKey else {
            throw WeatherServiceError.missingCoordinate
        }
        let period = trip.dateRange
        let cacheKey = WeatherCacheKey(tripId: trip.id, locationKey: locationKey, period: period)
        
        if !forceRefresh, let cached = validCachedReport(for: cacheKey) {
            return cached
        }
        
        if !appEnvironment.isOnline {
            if let cached = cachedReport(forKey: cacheKey) {
                let cachedReport = cached.withSource(.cache)
                inMemoryCache[cacheKey.rawValue] = cachedReport
                return cachedReport
            }
            throw WeatherServiceError.offlineDataUnavailable
        }
        
        do {
            let response = try await provider.fetchWeather(for: coordinate, period: period)
            let report = WeatherReport(tripId: trip.id,
                                       cacheKey: cacheKey.rawValue,
                                       location: coordinate,
                                       period: period,
                                       timezoneIdentifier: response.timezoneIdentifier,
                                       generatedAt: Date(),
                                       source: .live,
                                       daily: response.daily,
                                       hourly: response.hourly,
                                       providerMetadata: response.metadata)
            inMemoryCache[cacheKey.rawValue] = report
            try? cacheStore.save(report)
            return report
        } catch {
            if let cached = cachedReport(forKey: cacheKey) {
                let cachedReport = cached.withSource(.cache)
                inMemoryCache[cacheKey.rawValue] = cachedReport
                return cachedReport
            }
            throw error
        }
    }
    
    func cachedReport(for trip: Trip) -> WeatherReport? {
        guard let coordinate = trip.coordinate, let locationKey = trip.locationKey else {
            return nil
        }
        let cacheKey = WeatherCacheKey(tripId: trip.id, locationKey: locationKey, period: trip.dateRange)
        return cachedReport(forKey: cacheKey)?.withSource(.cache)
    }
    
    func clearCache(for trip: Trip) {
        guard let locationKey = trip.locationKey else { return }
        let key = WeatherCacheKey(tripId: trip.id, locationKey: locationKey, period: trip.dateRange)
        inMemoryCache.removeValue(forKey: key.rawValue)
        cacheStore.delete(for: key)
    }
    
    private func validCachedReport(for key: WeatherCacheKey) -> WeatherReport? {
        if let cached = inMemoryCache[key.rawValue], !cached.isExpired(ttl: cacheTTL) {
            return cached
        }
        if let stored = cacheStore.loadReport(for: key), !stored.isExpired(ttl: cacheTTL) {
            let cached = stored.withSource(.cache)
            inMemoryCache[key.rawValue] = cached
            return cached
        }
        return nil
    }
    
    private func cachedReport(forKey key: WeatherCacheKey) -> WeatherReport? {
        if let cached = inMemoryCache[key.rawValue] {
            return cached
        }
        if let stored = cacheStore.loadReport(for: key) {
            return stored
        }
        return nil
    }
}

protocol WeatherProvider {
    func fetchWeather(for coordinate: Coordinate, period: DateRange) async throws -> WeatherProviderResponse
}

final class WeatherKitWeatherProvider: WeatherProvider {
    private let service: WeatherKit.WeatherService
    
    init(service: WeatherKit.WeatherService = WeatherKit.WeatherService()) {
        self.service = service
    }
    
    func fetchWeather(for coordinate: Coordinate, period: DateRange) async throws -> WeatherProviderResponse {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let weather = try await service.weather(for: location)
        let calendar = Calendar.current
        
        let daily: [WeatherReport.DailySummary] = weather.dailyForecast.compactMap { day in
            guard period.contains(day.date, in: calendar) else { return nil }
            let high = day.highTemperature.converted(to: .celsius).value
            let low = day.lowTemperature.converted(to: .celsius).value
            return WeatherReport.DailySummary(
                date: day.date,
                highTemperature: high,
                lowTemperature: low,
                precipitationChance: day.precipitationChance,
                condition: normalizeCondition(from: day.condition),
                sunrise: nil,
                sunset: nil
            )
        }
        
        let hourly: [WeatherReport.HourlySummary] = weather.hourlyForecast.compactMap { hour in
            guard hour.date >= period.start && hour.date <= period.end else { return nil }
            let temperature = hour.temperature.converted(to: .celsius).value
            return WeatherReport.HourlySummary(
                date: hour.date,
                temperature: temperature,
                precipitationChance: hour.precipitationChance,
                condition: normalizeCondition(from: hour.condition)
            )
        }
        
        let timezoneIdentifier = weather.metadata.timeZone.identifier
        return WeatherProviderResponse(
            timezoneIdentifier: timezoneIdentifier,
            daily: daily,
            hourly: hourly,
            metadata: WeatherReport.ProviderMetadata(attribution: nil, dataset: nil)
        )
    }
    
    private func normalizeCondition(from condition: WeatherKit.WeatherCondition) -> NormalizedWeatherCondition {
        let key = condition.rawValue.lowercased()
        if key.contains("thunder") {
            return .thunderstorm
        }
        if key.contains("heavy") && key.contains("rain") {
            return .heavyRain
        }
        if key.contains("rain") || key.contains("drizzle") {
            return .rain
        }
        if key.contains("sleet") || key.contains("freezing") {
            return .sleet
        }
        if key.contains("snow") {
            return .snow
        }
        if key.contains("cloud") {
            if key.contains("partly") || key.contains("mostly") {
                return .partlyCloudy
            }
            return .cloudy
        }
        if key.contains("clear") {
            return key.contains("mostly") ? .mostlyClear : .clear
        }
        if key.contains("fog") {
            return .fog
        }
        if key.contains("wind") {
            return .windy
        }
        if key.contains("haze") {
            return .haze
        }
        if key.contains("smoke") {
            return .smoke
        }
        if key.contains("dust") {
            return .dust
        }
        if key.contains("hot") {
            return .hot
        }
        if key.contains("cold") {
            return .cold
        }
        if key.contains("hurricane") || key.contains("tropical") {
            return .tropicalStorm
        }
        return .unknown
    }
}
