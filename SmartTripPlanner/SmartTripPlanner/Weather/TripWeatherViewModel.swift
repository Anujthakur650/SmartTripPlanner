import CoreLocation
import Foundation

@MainActor
final class TripWeatherViewModel: ObservableObject {
    @Published private(set) var forecast: TripWeatherForecast?
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var error: Error?
    
    private let provider: WeatherProviding
    private var task: Task<Void, Never>?
    private let maxDays: Int
    
    init(provider: WeatherProviding = WeatherProvider(), maxDays: Int = 7) {
        self.provider = provider
        self.maxDays = maxDays
    }
    
    func loadWeather(for location: CLLocation?) {
        task?.cancel()
        guard let location else {
            error = NSError(domain: "TripWeatherViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing location"])
            return
        }
        isLoading = true
        error = nil
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let forecast = try await provider.forecast(for: location, days: maxDays)
                await MainActor.run {
                    self.forecast = forecast
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.forecast = nil
                    self.error = error
                    self.isLoading = false
                }
            }
        }
    }
    
    func cancel() {
        task?.cancel()
        task = nil
    }
}
