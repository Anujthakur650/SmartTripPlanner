import Foundation

actor DocumentStorageService {
    struct StoredFileDescriptor {
        let fileName: String
        let fileSize: Int64
        let kind: DocumentKind
    }
    
    private let fileManager: FileManager
    private let storageDirectory: URL
    private let metadataURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    
    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory
        self.storageDirectory = documentsDirectory.appendingPathComponent("DocumentAssets", isDirectory: true)
        self.metadataURL = storageDirectory.appendingPathComponent("documents.json")
        self.encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        try? ensureStorageDirectory()
    }
    
    func ensureStorageDirectory() throws {
        if !fileManager.fileExists(atPath: storageDirectory.path) {
            try fileManager.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
        }
    }
    
    func loadDocuments() throws -> [DocumentAsset] {
        try ensureStorageDirectory()
        guard fileManager.fileExists(atPath: metadataURL.path) else {
            return []
        }
        let data = try Data(contentsOf: metadataURL)
        guard !data.isEmpty else {
            return []
        }
        return try decoder.decode([DocumentAsset].self, from: data)
    }
    
    func persist(documents: [DocumentAsset]) throws {
        try ensureStorageDirectory()
        let data = try encoder.encode(documents)
        try data.write(to: metadataURL, options: .atomic)
    }
    
    func storeFile(from sourceURL: URL) throws -> StoredFileDescriptor {
        try ensureStorageDirectory()
        let fileExtension = sourceURL.pathExtension
        let uniqueName = UUID().uuidString + (fileExtension.isEmpty ? "" : ".\(fileExtension)")
        let destinationURL = storageDirectory.appendingPathComponent(uniqueName)
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
        return try makeDescriptor(for: destinationURL)
    }
    
    func storeData(_ data: Data, preferredExtension: String) throws -> StoredFileDescriptor {
        try ensureStorageDirectory()
        let ext = preferredExtension.isEmpty ? "bin" : preferredExtension
        let uniqueName = UUID().uuidString + ".\(ext)"
        let destinationURL = storageDirectory.appendingPathComponent(uniqueName)
        try data.write(to: destinationURL, options: .atomic)
        return try makeDescriptor(for: destinationURL)
    }
    
    func deleteFile(named fileName: String) throws {
        try ensureStorageDirectory()
        let url = storageDirectory.appendingPathComponent(fileName)
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }
    
    func url(for fileName: String) -> URL {
        storageDirectory.appendingPathComponent(fileName)
    }
    
    private func makeDescriptor(for url: URL) throws -> StoredFileDescriptor {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        let size = (attributes[.size] as? NSNumber)?.int64Value ?? 0
        let ext = url.pathExtension
        return StoredFileDescriptor(fileName: url.lastPathComponent, fileSize: size, kind: DocumentKind(fileExtension: ext))
    }
}
