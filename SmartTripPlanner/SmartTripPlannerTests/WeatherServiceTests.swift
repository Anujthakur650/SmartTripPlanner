@testable import SmartTripPlanner
import CoreLocation
import WeatherKit
import XCTest

final class WeatherServiceTests: XCTestCase {
    func testTripWeatherViewModelLoadsForecast() async throws {
        let forecast = TripWeatherForecast(summary: sampleSummary(), days: sampleDays(count: 3))
        let provider = MockWeatherProvider(result: .success(forecast))
        let viewModel = TripWeatherViewModel(provider: provider, maxDays: 3)
        let location = CLLocation(latitude: 37.7749, longitude: -122.4194)
        await MainActor.run {
            viewModel.loadWeather(for: location)
        }
        try await waitUntil { await MainActor.run { viewModel.forecast != nil && !viewModel.isLoading } }
        let loadedForecast = await MainActor.run { viewModel.forecast }
        XCTAssertEqual(loadedForecast, forecast)
        let error = await MainActor.run { viewModel.error }
        XCTAssertNil(error)
    }
    
    func testTripWeatherViewModelSetsErrorOnFailure() async throws {
        let provider = MockWeatherProvider(result: .failure(TestError.network))
        let viewModel = TripWeatherViewModel(provider: provider, maxDays: 3)
        await MainActor.run {
            viewModel.loadWeather(for: CLLocation(latitude: 0, longitude: 0))
        }
        try await waitUntil { await MainActor.run { viewModel.error != nil && !viewModel.isLoading } }
        let error = await MainActor.run { viewModel.error }
        XCTAssertNotNil(error)
        XCTAssertTrue(error is TestError)
        let forecast = await MainActor.run { viewModel.forecast }
        XCTAssertNil(forecast)
    }
    
    func testTripWeatherViewModelCancelStopsLoading() async throws {
        let provider = MockWeatherProvider(result: .success(sampleForecast()))
        let viewModel = TripWeatherViewModel(provider: provider, maxDays: 5)
        await MainActor.run {
            viewModel.loadWeather(for: CLLocation(latitude: 10, longitude: 10))
            viewModel.cancel()
        }
        try await Task.sleep(nanoseconds: 50_000_000)
        let isLoading = await MainActor.run { viewModel.isLoading }
        XCTAssertFalse(isLoading)
    }
    
    // MARK: - Helpers
    
    private func waitUntil(timeout: TimeInterval = 1.0, predicate: @escaping () async -> Bool) async throws {
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            if await predicate() { return }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTFail("Condition not met within \(timeout) seconds")
    }
    
    private func sampleSummary() -> TripWeatherSummary {
        TripWeatherSummary(condition: .clear,
                           temperature: Measurement(value: 22, unit: UnitTemperature.celsius),
                           high: Measurement(value: 24, unit: UnitTemperature.celsius),
                           low: Measurement(value: 18, unit: UnitTemperature.celsius),
                           precipitationChance: 0.1)
    }
    
    private func sampleDays(count: Int) -> [TripWeatherDay] {
        (0..<count).map { index in
            TripWeatherDay(date: Calendar.current.date(byAdding: .day, value: index, to: Date())!,
                           condition: .clear,
                           high: Measurement(value: 24 + Double(index), unit: UnitTemperature.celsius),
                           low: Measurement(value: 18 + Double(index), unit: UnitTemperature.celsius),
                           precipitationChance: 0.1,
                           symbolName: "sun.max.fill",
                           windSpeed: Measurement(value: 12, unit: UnitSpeed.kilometersPerHour))
        }
    }
    
    private func sampleForecast() -> TripWeatherForecast {
        TripWeatherForecast(summary: sampleSummary(), days: sampleDays(count: 5))
    }
}

private final class MockWeatherProvider: WeatherProviding {
    var result: Result<TripWeatherForecast, Error>
    
    init(result: Result<TripWeatherForecast, Error>) {
        self.result = result
    }
    
    func forecast(for location: CLLocation, days: Int) async throws -> TripWeatherForecast {
        switch result {
        case let .success(forecast):
            return forecast
        case let .failure(error):
            throw error
        }
    }
}

private enum TestError: Error {
    case network
}
