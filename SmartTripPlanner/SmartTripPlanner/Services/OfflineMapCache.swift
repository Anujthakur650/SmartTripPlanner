import Foundation
import MapKit

actor OfflineMapCache {
    private let cacheDir: URL
    private var cachedRegions: [String: CachedRegion] = [:]
    
    init() {
        let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        cacheDir = cachesDir.appendingPathComponent("OfflineMaps")
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }
    
    func cacheMapSnapshot(for location: CLLocationCoordinate2D, radius: CLLocationDistance) async throws {
        let key = "\(location.latitude)_\(location.longitude)"
        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(center: location, latitudinalMeters: radius, longitudinalMeters: radius)
        options.size = CGSize(width: 1024, height: 1024)
        
        let snapshotter = MKMapSnapshotter(options: options)
        let snapshot = try await snapshotter.start()
        
        if let imageData = snapshot.image.pngData() {
            let fileURL = cacheDir.appendingPathComponent("\(key).png")
            try imageData.write(to: fileURL)
            cachedRegions[key] = CachedRegion(location: location, fileURL: fileURL, cachedAt: Date())
        }
    }
    
    func getCachedSnapshot(for location: CLLocationCoordinate2D) -> URL? {
        let key = "\(location.latitude)_\(location.longitude)"
        return cachedRegions[key]?.fileURL
    }
}

struct CachedRegion {
    let location: CLLocationCoordinate2D
    let fileURL: URL
    let cachedAt: Date
}
