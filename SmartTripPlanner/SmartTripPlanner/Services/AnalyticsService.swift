import Combine
import Foundation

@MainActor
final class AnalyticsService: ObservableObject {
    enum MapAnalyticsEvent: String {
        case searchStarted
        case searchSucceeded
        case searchFailed
        case suggestionSelected
        case placeSaved
        case placeBookmarkToggled
        case routeRequested
        case routeSucceeded
        case routeFailed
        case routeSaved
        case openInAppleMaps
    }
    
    @Published var isEnabled: Bool
    @Published var diagnosticsOptIn: Bool
    
    init(isEnabled: Bool = true, diagnosticsOptIn: Bool = false) {
        self.isEnabled = isEnabled
        self.diagnosticsOptIn = diagnosticsOptIn
    }
    
    func log(event name: String, metadata: [String: String]? = nil) {
        guard isEnabled else { return }
        #if DEBUG
        if let metadata = metadata, !metadata.isEmpty {
            print("[Analytics] \(name): \(metadata)")
        } else {
            print("[Analytics] \(name)")
        }
        #endif
    }
    
    func log(map event: MapAnalyticsEvent, metadata: [String: String]? = nil) {
        log(event: "map_\(event.rawValue)", metadata: metadata)
    }
    
    func logDiagnostics(event name: String, metadata: [String: String]? = nil) {
        guard diagnosticsOptIn else { return }
        log(event: name, metadata: metadata)
    }
}
