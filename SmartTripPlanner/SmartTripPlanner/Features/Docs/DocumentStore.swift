import Foundation
import CryptoKit

actor DocumentStore {
    enum StoreError: LocalizedError, Identifiable {
        case underlying(Error)
        case documentNotFound
        case failedToPersist
        case invalidScan
        
        var id: String { localizedDescription }
        
        var errorDescription: String? {
            switch self {
            case let .underlying(error):
                return error.localizedDescription
            case .documentNotFound:
                return "The document could not be found."
            case .failedToPersist:
                return "We couldn't save your documents securely."
            case .invalidScan:
                return "The scanned document was invalid."
            }
        }
        
        var recoverySuggestion: String? {
            switch self {
            case .underlying:
                return "Please try again."
            case .failedToPersist:
                return "Check your available storage space and try again."
            case .documentNotFound, .invalidScan:
                return nil
            }
        }
    }
    
    private struct StoredDocuments: Codable {
        var documents: [TravelDocument]
    }
    
    nonisolated let directory: URL
    private let metadataURL: URL
    private var cache: [TravelDocument] = []
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let fileManager: FileManager
    private let metadataFileOptions: Data.WritingOptions = [.atomic, .completeFileProtection]
    private let documentFileOptions: Data.WritingOptions = [.completeFileProtection]
    
    init(directory: URL? = nil, fileManager: FileManager = .default) throws {
        let resolvedDirectory: URL
        if let directory {
            resolvedDirectory = directory
        } else {
            let support = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            resolvedDirectory = support.appendingPathComponent("Documents", isDirectory: true)
        }
        if !fileManager.fileExists(atPath: resolvedDirectory.path) {
            try fileManager.createDirectory(at: resolvedDirectory, withIntermediateDirectories: true)
        }
        self.directory = resolvedDirectory
        self.metadataURL = resolvedDirectory.appendingPathComponent("documents.json")
        self.fileManager = fileManager
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
        try loadCacheFromDisk()
    }
    
    func documents() -> [TravelDocument] {
        cache.sorted { $0.updatedAt > $1.updatedAt }
    }
    
    func refresh() throws -> [TravelDocument] {
        try loadCacheFromDisk()
        return documents()
    }
    
    func addDocument(data: Data, metadata: TravelDocument.Metadata, pageCount: Int) throws -> TravelDocument {
        guard !data.isEmpty else { throw StoreError.invalidScan }
        let id = UUID()
        let fileName = "\(id.uuidString).pdf"
        let fileURL = directory.appendingPathComponent(fileName)
        do {
            try data.write(to: fileURL, options: documentFileOptions)
        } catch {
            throw StoreError.underlying(error)
        }
        let checksum = sha256Hex(of: data)
        let now = Date()
        let document = TravelDocument(
            id: id,
            metadata: metadata,
            fileName: fileName,
            createdAt: now,
            updatedAt: now,
            pageCount: pageCount,
            fileSize: data.count,
            checksum: checksum
        )
        cache.append(document)
        try persist()
        return document
    }
    
    func updateDocument(_ document: TravelDocument, metadata: TravelDocument.Metadata) throws -> TravelDocument {
        guard let index = cache.firstIndex(where: { $0.id == document.id }) else {
            throw StoreError.documentNotFound
        }
        var updated = cache[index]
        updated.metadata = metadata
        updated.updatedAt = Date()
        cache[index] = updated
        try persist()
        return updated
    }
    
    func deleteDocument(_ document: TravelDocument) throws {
        guard let index = cache.firstIndex(where: { $0.id == document.id }) else {
            throw StoreError.documentNotFound
        }
        let fileURL = url(for: document)
        do {
            if fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
            }
        } catch {
            throw StoreError.underlying(error)
        }
        cache.remove(at: index)
        try persist()
    }
    
    nonisolated func url(for document: TravelDocument) -> URL {
        directory.appendingPathComponent(document.fileName)
    }
    
    private func loadCacheFromDisk() throws {
        guard fileManager.fileExists(atPath: metadataURL.path) else {
            cache = []
            return
        }
        do {
            let data = try Data(contentsOf: metadataURL)
            let stored = try decoder.decode(StoredDocuments.self, from: data)
            cache = stored.documents
        } catch {
            throw StoreError.underlying(error)
        }
    }
    
    private func persist() throws {
        do {
            let data = try encoder.encode(StoredDocuments(documents: cache))
            try data.write(to: metadataURL, options: metadataFileOptions)
        } catch {
            throw StoreError.failedToPersist
        }
    }
    
    private func sha256Hex(of data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
