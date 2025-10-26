import Foundation
import CoreLocation

@MainActor
final class TripWeatherViewModel: ObservableObject {
    enum State: Equatable {
        case idle
        case noTrips
        case loading(tripName: String?)
        case content(summary: WeatherSummary, trip: Trip)
        case error(message: String, suggestion: String?)
        
        static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.noTrips, .noTrips):
                return true
            case let (.loading(lName), .loading(rName)):
                return lName == rName
            case let (.content(lSummary, lTrip), .content(rSummary, rTrip)):
                return lSummary == rSummary && lTrip == rTrip
            case let (.error(lMessage, lSuggestion), .error(rMessage, rSuggestion)):
                return lMessage == rMessage && lSuggestion == rSuggestion
            default:
                return false
            }
        }
    }
    
    @Published private(set) var state: State = .idle
    @Published private(set) var activeTrip: Trip?
    @Published private(set) var lastError: WeatherService.ServiceError?
    
    private var weatherService: WeatherService?
    private var fetchTask: Task<Void, Never>?
    private let geocoder: Geocoding
    
    init(geocoder: Geocoding = CLGeocoder()) {
        self.geocoder = geocoder
    }
    
    func configure(with container: DependencyContainer) {
        guard weatherService == nil else { return }
        weatherService = container.weatherService
    }
    
    func refresh(for trips: [Trip]) {
        fetchTask?.cancel()
        guard let service = weatherService else { return }
        guard let trip = upcomingTrip(from: trips) else {
            activeTrip = nil
            state = trips.isEmpty ? .noTrips : .error(message: "Add a destination to see weather details.", suggestion: nil)
            return
        }
        activeTrip = trip
        state = .loading(tripName: trip.name)
        fetchTask = Task { [weak self] in
            await self?.loadWeather(for: trip, service: service)
        }
    }
    
    func retry() {
        if let activeTrip {
            refresh(for: [activeTrip])
        }
    }
    
    private func upcomingTrip(from trips: [Trip]) -> Trip? {
        return trips
            .filter { !$0.destination.trimmingCharacters(in: .whitespaces).isEmpty }
            .sorted { $0.startDate < $1.startDate }
            .first
    }
    
    private func loadWeather(for trip: Trip, service: WeatherService) async {
        do {
            let placemarks = try await geocoder.geocode(address: trip.destination)
            guard let placemark = placemarks.first, let location = placemark.location else {
                await updateForError(.failedToLoad("We couldn't find that destination."))
                return
            }
            let localityComponents = [placemark.locality, placemark.administrativeArea, placemark.country]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
            let displayName = localityComponents.isEmpty ? trip.destination : localityComponents.joined(separator: ", ")
            let summary = try await service.summary(for: location, preferredName: displayName, cacheKey: trip.id.uuidString)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.lastError = nil
                self.state = .content(summary: summary, trip: trip)
            }
        } catch let error as WeatherService.ServiceError {
            await updateForError(error)
        } catch let error as CLError {
            await updateForError(serviceError(for: error))
        } catch {
            await updateForError(.failedToLoad(error.localizedDescription))
        }
    }
    
    private func serviceError(for error: CLError) -> WeatherService.ServiceError {
        switch error.code {
        case .denied, .restricted:
            return .notAuthorized
        case .network:
            return .networkUnavailable(error.localizedDescription)
        default:
            return .failedToLoad(error.localizedDescription)
        }
    }
    
    private func updateForError(_ serviceError: WeatherService.ServiceError) async {
        guard !Task.isCancelled else { return }
        await MainActor.run {
            self.lastError = serviceError
            self.state = .error(message: serviceError.errorDescription ?? "Weather is unavailable.", suggestion: serviceError.recoverySuggestion)
        }
    }
}

protocol Geocoding {
    func geocode(address: String) async throws -> [CLPlacemark]
}

extension CLGeocoder: Geocoding {
    func geocode(address: String) async throws -> [CLPlacemark] {
        try await withCheckedThrowingContinuation { continuation in
            self.geocodeAddressString(address) { placemarks, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let placemarks {
                    continuation.resume(returning: placemarks)
                } else {
                    continuation.resume(throwing: CLError(.geocodeFoundNoResult))
                }
            }
        }
    }
}
