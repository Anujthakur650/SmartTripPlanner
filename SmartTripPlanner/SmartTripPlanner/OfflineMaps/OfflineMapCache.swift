import Foundation
import MapKit
import UIKit

protocol OfflineMapCaching {
    func prewarm(for trip: Trip, places: [Place], span: MKCoordinateSpan) async
    func image(for identifier: String) -> UIImage?
    func clearExpired(olderThan date: Date)
}

protocol MapSnapshotGenerating {
    func snapshot(for options: MKMapSnapshotter.Options) async throws -> MKMapSnapshot
}

struct MapSnapshotGenerator: MapSnapshotGenerating {
    func snapshot(for options: MKMapSnapshotter.Options) async throws -> MKMapSnapshot {
        let snapshotter = MKMapSnapshotter(options: options)
        return try await snapshotter.start()
    }
}

final class OfflineMapCache {
    struct CacheEntry: Codable {
        var identifier: String
        var filename: String
        var createdAt: Date
        var lastAccessed: Date
        var byteCount: Int64
        var center: Coordinate
        var spanLatitudeDelta: CLLocationDegrees
        var spanLongitudeDelta: CLLocationDegrees
    }
    
    enum CacheError: LocalizedError {
        case snapshotFailed
        case writeFailed
        case entryNotFound
        case diskQuotaExceeded
        case unknown(Error)
        
        var errorDescription: String? {
            switch self {
            case .snapshotFailed:
                return "Unable to generate map snapshot."
            case .writeFailed:
                return "Saving the offline map failed."
            case .entryNotFound:
                return "Offline map not found."
            case .diskQuotaExceeded:
                return "Offline map cache quota exceeded."
            case let .unknown(error):
                return error.localizedDescription
            }
        }
    }
    
    private let ioQueue = DispatchQueue(label: "com.smarttripplanner.offlinemapcache")
    private let fileManager: FileManager
    private let cacheDirectory: URL
    private let indexURL: URL
    private let maxDiskUsage: Int64
    private var index: [String: CacheEntry] = [:]
    private let snapshotGenerator: MapSnapshotGenerating
    
    init(fileManager: FileManager = .default,
         directoryName: String = "OfflineMaps",
         maxDiskUsageMb: Int = 300,
         snapshotGenerator: MapSnapshotGenerating = MapSnapshotGenerator()) {
        self.fileManager = fileManager
        self.snapshotGenerator = snapshotGenerator
        let baseDirectory: URL
        if let appSupport = try? fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true) {
            baseDirectory = appSupport
        } else {
            baseDirectory = fileManager.temporaryDirectory
        }
        cacheDirectory = baseDirectory.appendingPathComponent("SmartTripPlanner", isDirectory: true)
            .appendingPathComponent(directoryName, isDirectory: true)
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
        indexURL = cacheDirectory.appendingPathComponent("index.json")
        maxDiskUsage = Int64(maxDiskUsageMb) * 1_024 * 1_024
        loadIndex()
    }
    
    func cacheSnapshot(identifier: String,
                       center: CLLocationCoordinate2D,
                       span: MKCoordinateSpan,
                       size: CGSize = CGSize(width: 600, height: 600),
                       scale: CGFloat = UIScreen.main.scale) async throws {
        let options = MKMapSnapshotter.Options()
        options.mapType = .standard
        options.showsBuildings = true
        options.pointOfInterestFilter = .includingAll
        options.region = MKCoordinateRegion(center: center, span: span)
        options.size = size
        options.scale = scale
        let snapshot = try await snapshotGenerator.snapshot(for: options)
        guard let data = snapshot.image.pngData() else {
            throw CacheError.snapshotFailed
        }
        var thrownError: Error?
        ioQueue.sync {
            do {
                let filename = "\(identifier).png"
                let fileURL = cacheDirectory.appendingPathComponent(filename)
                try data.write(to: fileURL, options: .atomic)
                let entry = CacheEntry(identifier: identifier,
                                       filename: filename,
                                       createdAt: Date(),
                                       lastAccessed: Date(),
                                       byteCount: Int64(data.count),
                                       center: Coordinate(latitude: center.latitude, longitude: center.longitude),
                                       spanLatitudeDelta: span.latitudeDelta,
                                       spanLongitudeDelta: span.longitudeDelta)
                index[identifier] = entry
                try persistIndex()
                try enforceDiskQuota()
            } catch {
                thrownError = error
            }
        }
        if let error = thrownError {
            if let cacheError = error as? CacheError {
                throw cacheError
            }
            throw CacheError.unknown(error)
        }
    }
    
    func image(for identifier: String) -> UIImage? {
        ioQueue.sync {
            guard let entry = index[identifier] else { return nil }
            let fileURL = cacheDirectory.appendingPathComponent(entry.filename)
            guard let data = try? Data(contentsOf: fileURL), let image = UIImage(data: data) else {
                return nil
            }
            var updatedEntry = entry
            updatedEntry.lastAccessed = Date()
            index[identifier] = updatedEntry
            try? persistIndex()
            return image
        }
    }
    
    func clearExpired(olderThan date: Date) {
        ioQueue.async {
            let expired = self.index.values.filter { $0.lastAccessed < date }
            expired.forEach { entry in
                let fileURL = self.cacheDirectory.appendingPathComponent(entry.filename)
                try? self.fileManager.removeItem(at: fileURL)
                self.index.removeValue(forKey: entry.identifier)
            }
            try? self.persistIndex()
        }
    }
    
    func removeAll() {
        ioQueue.async {
            for entry in self.index.values {
                let fileURL = self.cacheDirectory.appendingPathComponent(entry.filename)
                try? self.fileManager.removeItem(at: fileURL)
            }
            self.index.removeAll()
            try? self.persistIndex()
        }
    }
    
    func prewarm(for trip: Trip, places: [Place], span: MKCoordinateSpan = MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)) async {
        await withTaskGroup(of: Void.self) { group in
            for place in places {
                group.addTask {
                    guard place.coordinateKey.isEmpty == false else { return }
                    try? await self.cacheSnapshot(identifier: place.coordinateKey,
                                                  center: place.coordinate.locationCoordinate,
                                                  span: span)
                }
            }
            for reservation in trip.reservations {
                if let origin = reservation.origin?.coordinate?.locationCoordinate {
                    let identifier = "reservation-\(reservation.id.uuidString)-origin"
                    group.addTask {
                        try? await self.cacheSnapshot(identifier: identifier,
                                                      center: origin,
                                                      span: span)
                    }
                }
                if let destination = reservation.destination?.coordinate?.locationCoordinate {
                    let identifier = "reservation-\(reservation.id.uuidString)-destination"
                    group.addTask {
                        try? await self.cacheSnapshot(identifier: identifier,
                                                      center: destination,
                                                      span: span)
                    }
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func loadIndex() {
        ioQueue.sync {
            guard let data = try? Data(contentsOf: indexURL) else {
                index = [:]
                try? persistIndex()
                return
            }
            do {
                let decoded = try JSONDecoder().decode([String: CacheEntry].self, from: data)
                index = decoded
            } catch {
                index = [:]
                try? persistIndex()
            }
        }
    }
    
    private func persistIndex() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(index)
        try data.write(to: indexURL, options: .atomic)
    }
    
    private func enforceDiskQuota() throws {
        let total = index.values.reduce(Int64(0)) { $0 + $1.byteCount }
        guard total > maxDiskUsage else { return }
        let sorted = index.values.sorted { $0.lastAccessed < $1.lastAccessed }
        var bytesToFree = total - maxDiskUsage
        for entry in sorted {
            let fileURL = cacheDirectory.appendingPathComponent(entry.filename)
            try? fileManager.removeItem(at: fileURL)
            index.removeValue(forKey: entry.identifier)
            bytesToFree -= entry.byteCount
            if bytesToFree <= 0 { break }
        }
        if bytesToFree > 0 {
            throw CacheError.diskQuotaExceeded
        }
        try persistIndex()
    }
}

extension OfflineMapCache: OfflineMapCaching {}
