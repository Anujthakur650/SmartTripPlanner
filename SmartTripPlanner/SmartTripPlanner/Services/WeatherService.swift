import Foundation
import CoreLocation

@MainActor
final class WeatherService: ObservableObject {
    enum ServiceError: LocalizedError, Identifiable, Equatable {
        case notAuthorized
        case networkUnavailable(String?)
        case failedToLoad(String?)
        case unknown
        
        var id: String { localizedDescription }
        
        var errorDescription: String? {
            switch self {
            case .notAuthorized:
                return "Weather access requires WeatherKit entitlements and appropriate permissions."
            case let .networkUnavailable(message):
                return message ?? "Weather data is unavailable while offline."
            case let .failedToLoad(message):
                return message ?? "We couldn't load the latest weather right now."
            case .unknown:
                return "An unknown weather error occurred."
            }
        }
        
        var recoverySuggestion: String? {
            switch self {
            case .notAuthorized:
                return "Check that WeatherKit is enabled for the app and try again."
            case .networkUnavailable:
                return "Reconnect to the internet and refresh."
            case .failedToLoad:
                return "Please try refreshing in a moment."
            case .unknown:
                return nil
            }
        }
    }
    
    private struct CacheEntry {
        let summary: WeatherSummary
        let expiry: Date
    }
    
    private let provider: WeatherDataProvider
    private let cacheDuration: TimeInterval
    private var cache: [String: CacheEntry] = [:]
    
    init(provider: WeatherDataProvider = WeatherKitProvider(), cacheDuration: TimeInterval = 60 * 30) {
        self.provider = provider
        self.cacheDuration = cacheDuration
    }
    
    func summary(for location: CLLocation, preferredName: String? = nil, cacheKey customKey: String? = nil, days: Int = 7) async throws -> WeatherSummary {
        let cacheKey = makeCacheKey(for: location, customKey: customKey)
        if let entry = cache[cacheKey], entry.expiry > Date() {
            return applyPreferredName(entry.summary, name: preferredName)
        }
        do {
            var summary = try await provider.fetchWeather(for: location, days: days)
            summary = applyPreferredName(summary, name: preferredName)
            cache[cacheKey] = CacheEntry(summary: summary, expiry: Date().addingTimeInterval(cacheDuration))
            return summary
        } catch let error as CLError {
            throw mapCLError(error)
        } catch {
            throw mapGenericError(error)
        }
    }
    
    func cachedSummary(for key: String) -> WeatherSummary? {
        guard let entry = cache[key], entry.expiry > Date() else { return nil }
        return entry.summary
    }
    
    func clearCache(for key: String? = nil) {
        if let key {
            cache.removeValue(forKey: key)
        } else {
            cache.removeAll()
        }
    }
    
    private func makeCacheKey(for location: CLLocation, customKey: String?) -> String {
        if let customKey {
            return customKey
        }
        return String(format: "%0.4f-%0.4f", location.coordinate.latitude, location.coordinate.longitude)
    }
    
    private func applyPreferredName(_ summary: WeatherSummary, name: String?) -> WeatherSummary {
        guard let name, !name.isEmpty else { return summary }
        return summary.withLocationName(name)
    }
    
    private func mapCLError(_ error: CLError) -> ServiceError {
        switch error.code {
        case .denied, .restricted:
            return .notAuthorized
        case .network:
            return .networkUnavailable(error.localizedDescription)
        default:
            return .failedToLoad(error.localizedDescription)
        }
    }
    
    private func mapGenericError(_ error: Error) -> ServiceError {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return .networkUnavailable(nsError.localizedDescription)
        }
        if nsError.domain == "WeatherService" && nsError.code == 1 {
            return .notAuthorized
        }
        if nsError.localizedDescription.isEmpty {
            return .unknown
        }
        return .failedToLoad(nsError.localizedDescription)
    }
}
