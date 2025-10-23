import Foundation

final class WeatherCacheStore {
    private let directory: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    
    init(directory: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let baseDirectory = directory ?? WeatherCacheStore.defaultDirectory(fileManager: fileManager)
        self.directory = baseDirectory
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        createDirectoryIfNeeded()
    }
    
    func loadReport(for key: WeatherCacheKey) -> WeatherReport? {
        let url = directory.appendingPathComponent(key.fileName)
        guard fileManager.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? decoder.decode(WeatherReport.self, from: data)
    }
    
    func save(_ report: WeatherReport) throws {
        let url = directory.appendingPathComponent(report.cacheKey + ".json")
        let data = try encoder.encode(report)
        try data.write(to: url, options: .atomic)
    }
    
    func delete(for key: WeatherCacheKey) {
        let url = directory.appendingPathComponent(key.fileName)
        if fileManager.fileExists(atPath: url.path) {
            try? fileManager.removeItem(at: url)
        }
    }
    
    func clear() {
        guard fileManager.fileExists(atPath: directory.path) else { return }
        if let files = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
            for file in files where file.pathExtension == "json" {
                try? fileManager.removeItem(at: file)
            }
        }
    }
    
    private func createDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: directory.path) {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }
    
    private static func defaultDirectory(fileManager: FileManager) -> URL {
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory
        return caches.appendingPathComponent("WeatherCache", isDirectory: true)
    }
}
