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
        case offlineDownloadRequested
        case offlineDownloadCompleted
        case offlineDownloadFailed
        case offlineDownloadCancelled
        case offlineRegionDeleted
        case offlineRegionUpdated
    }
    
    func log(event name: String, metadata: [String: String]? = nil) {
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
}
