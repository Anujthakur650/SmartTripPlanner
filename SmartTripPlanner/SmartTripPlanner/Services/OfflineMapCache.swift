import Foundation
import MapKit
import UIKit

actor OfflineMapCache {
    private let directory: URL
    private var cache: [String: URL] = [:]
    private let fileManager = FileManager.default
    
    init(directory: URL? = nil) {
        if let directory {
            self.directory = directory
        } else {
            let base = fileManager.temporaryDirectory.appendingPathComponent("OfflineMaps", isDirectory: true)
            if !fileManager.fileExists(atPath: base.path) {
                try? fileManager.createDirectory(at: base, withIntermediateDirectories: true)
            }
            self.directory = base
        }
        loadExistingSnapshots()
    }
    
    func snapshotURL(for place: Place) -> URL? {
        cache[place.cacheIdentifier]
    }
    
    func ensureSnapshot(for place: Place, size: CGSize = CGSize(width: 600, height: 400)) async throws -> URL {
        if let existing = cache[place.cacheIdentifier], fileManager.fileExists(atPath: existing.path) {
            return existing
        }
        let url = directory.appendingPathComponent("\(place.cacheIdentifier).png")
        let options = MKMapSnapshotter.Options()
        let span = MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        options.region = MKCoordinateRegion(center: place.coordinate.locationCoordinate, span: span)
        options.size = size
        options.showsBuildings = true
        options.showsPointsOfInterest = true
        let snapshot = try await makeSnapshot(options: options)
        guard let data = snapshot.pngData() else {
            throw NSError(domain: "OfflineMapCache", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode snapshot"])
        }
        try data.write(to: url, options: [.atomic])
        cache[place.cacheIdentifier] = url
        return url
    }
    
    func removeSnapshot(for place: Place) {
        guard let url = cache[place.cacheIdentifier] else { return }
        try? fileManager.removeItem(at: url)
        cache.removeValue(forKey: place.cacheIdentifier)
    }
    
    private func makeSnapshot(options: MKMapSnapshotter.Options) async throws -> UIImage {
        try await withCheckedThrowingContinuation { continuation in
            let snapshotter = MKMapSnapshotter(options: options)
            snapshotter.start { snapshot, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                if let image = snapshot?.image {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(throwing: NSError(domain: "OfflineMapCache", code: -2, userInfo: [NSLocalizedDescriptionKey: "Snapshot missing image"]))
                }
            }
        }
    }
    
    private func loadExistingSnapshots() {
        guard let files = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return }
        for file in files where file.pathExtension.lowercased() == "png" {
            let key = file.deletingPathExtension().lastPathComponent
            cache[key] = file
        }
    }
}

private extension Place {
    var cacheIdentifier: String {
        "\(coordinateKey)\(id.uuidString.prefix(6))"
    }
}
