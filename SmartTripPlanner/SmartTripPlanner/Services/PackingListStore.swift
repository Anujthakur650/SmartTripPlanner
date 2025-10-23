import Foundation

final class PackingListStore {
    private let directory: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    
    init(directory: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        encoder.outputFormatting = [.prettyPrinted]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        if let directory {
            self.directory = directory
        } else {
            let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory
            self.directory = documents.appendingPathComponent("PackingLists", isDirectory: true)
        }
        createDirectoryIfNeeded()
    }
    
    func loadList(for tripId: UUID) -> TripPackingList? {
        let url = fileURL(for: tripId)
        guard fileManager.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? decoder.decode(TripPackingList.self, from: data)
    }
    
    func saveList(_ list: TripPackingList) throws {
        let url = fileURL(for: list.tripId)
        let data = try encoder.encode(list)
        try data.write(to: url, options: .atomic)
    }
    
    func deleteList(for tripId: UUID) {
        let url = fileURL(for: tripId)
        if fileManager.fileExists(atPath: url.path) {
            try? fileManager.removeItem(at: url)
        }
    }
    
    func loadAll() -> [UUID: TripPackingList] {
        guard let files = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            return [:]
        }
        var result: [UUID: TripPackingList] = [:]
        for file in files where file.pathExtension == "json" {
            guard let data = try? Data(contentsOf: file),
                  let list = try? decoder.decode(TripPackingList.self, from: data) else { continue }
            result[list.tripId] = list
        }
        return result
    }
    
    private func fileURL(for tripId: UUID) -> URL {
        directory.appendingPathComponent("\(tripId.uuidString).json")
    }
    
    private func createDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: directory.path) {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }
}
