import CryptoKit
import Foundation
import os.log
import Security

final class DocumentStore: ObservableObject {
    enum StoreError: LocalizedError {
        case encodingFailure
        case decodingFailure
        case writeFailure
        case readFailure
        case documentNotFound
        case diskQuotaExceeded
        case encryptionFailure
        case decryptionFailure
        case unknown(Error)
        
        var errorDescription: String? {
            switch self {
            case .encodingFailure:
                return "Unable to encode the document metadata."
            case .decodingFailure:
                return "Unable to decode the document metadata."
            case .writeFailure:
                return "Writing the document to disk failed."
            case .readFailure:
                return "Reading the document from disk failed."
            case .documentNotFound:
                return "The document could not be found."
            case .diskQuotaExceeded:
                return "Not enough space to store the document."
            case .encryptionFailure:
                return "Encrypting the document failed."
            case .decryptionFailure:
                return "Decrypting the document failed."
            case let .unknown(error):
                return error.localizedDescription
            }
        }
    }
    
    private struct Index: Codable {
        var documents: [TravelDocument]
        var totalSize: Int64
    }
    
    private let fileManager: FileManager
    private let directoryURL: URL
    private let indexURL: URL
    private let keyURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let logger = Logger(subsystem: "com.smarttripplanner.documentstore", category: "DocumentStore")
    private let ioQueue = DispatchQueue(label: "com.smarttripplanner.documentstore", qos: .userInitiated)
    private let encryptionKey: SymmetricKey
    
    @Published private(set) var documents: [TravelDocument] = []
    var maxDiskUsage: Int64
    
    init(fileManager: FileManager = .default,
         directoryName: String = "Documents",
         maxDiskUsage: Int64 = 512 * 1_024 * 1_024,
         baseURL: URL? = nil) {
        self.fileManager = fileManager
        self.maxDiskUsage = maxDiskUsage
        let rootDirectory: URL
        if let baseURL {
            rootDirectory = baseURL
        } else if let appSupport = try? fileManager.url(for: .applicationSupportDirectory,
                                                        in: .userDomainMask,
                                                        appropriateFor: nil,
                                                        create: true) {
            rootDirectory = appSupport
        } else {
            rootDirectory = fileManager.temporaryDirectory
        }
        directoryURL = rootDirectory.appendingPathComponent("SmartTripPlanner", isDirectory: true)
            .appendingPathComponent(directoryName, isDirectory: true)
        indexURL = directoryURL.appendingPathComponent("index.json")
        keyURL = directoryURL.appendingPathComponent("key.bin")
        encoder = JSONEncoder()
        decoder = JSONDecoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        
        if !fileManager.fileExists(atPath: directoryURL.path) {
            try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }
        encryptionKey = DocumentStore.loadOrCreateKey(at: keyURL)
        loadIndex()
    }
    
    func reload() {
        loadIndex()
    }
    
    func storeDocument(data: Data, metadata: TravelDocumentMetadata, preferredFilename: String? = nil) throws -> TravelDocument {
        try ioQueue.sync {
            let identifier = UUID()
            let baseName = preferredFilename?.trimmingCharacters(in: .whitespacesAndNewlines)
            let sanitizedName = DocumentStore.sanitizedFilename(baseName?.isEmpty == false ? baseName! : metadata.title)
            let filename = "\(sanitizedName)-\(identifier.uuidString).dat"
            let fileURL = directoryURL.appendingPathComponent(filename)
            let encryptedData = try encrypt(data)
            try reclaimSpaceIfNeeded(for: Int64(encryptedData.count))
            do {
                try encryptedData.write(to: fileURL, options: .completeFileProtectionUnlessOpen)
            } catch {
                logger.error("Failed to write encrypted document: \(error.localizedDescription)")
                throw StoreError.writeFailure
            }
            var document = TravelDocument(id: identifier,
                                          filename: filename,
                                          metadata: metadata,
                                          createdAt: Date(),
                                          updatedAt: Date(),
                                          fileSize: Int64(encryptedData.count))
            document.metadata.lastViewedAt = Date()
            documents.append(document)
            persistIndex()
            return document
        }
    }
    
    func updateMetadata(for documentId: UUID, transform: (inout TravelDocumentMetadata) -> Void) throws {
        try ioQueue.sync {
            guard let index = documents.firstIndex(where: { $0.id == documentId }) else {
                throw StoreError.documentNotFound
            }
            var document = documents[index]
            transform(&document.metadata)
            document.metadata.lastViewedAt = Date()
            document.updatedAt = Date()
            documents[index] = document
            persistIndex()
        }
    }
    
    func deleteDocument(id: UUID) throws {
        try ioQueue.sync {
            guard let index = documents.firstIndex(where: { $0.id == id }) else {
                throw StoreError.documentNotFound
            }
            let document = documents.remove(at: index)
            let fileURL = directoryURL.appendingPathComponent(document.filename)
            do {
                if fileManager.fileExists(atPath: fileURL.path) {
                    try fileManager.removeItem(at: fileURL)
                }
            } catch {
                logger.error("Failed to remove file: \(error.localizedDescription)")
                throw StoreError.writeFailure
            }
            persistIndex()
        }
    }
    
    func data(for document: TravelDocument) throws -> Data {
        try ioQueue.sync {
            let fileURL = directoryURL.appendingPathComponent(document.filename)
            guard let encrypted = try? Data(contentsOf: fileURL) else {
                throw StoreError.readFailure
            }
            return try decrypt(encrypted)
        }
    }
    
    func totalDiskUsage() -> Int64 {
        documents.reduce(0) { $0 + $1.fileSize }
    }
    
    // MARK: - Private helpers
    
    private func loadIndex() {
        ioQueue.sync {
            guard let data = try? Data(contentsOf: indexURL) else {
                documents = []
                persistIndex()
                return
            }
            do {
                let index = try decoder.decode(Index.self, from: data)
                documents = index.documents.sorted { $0.updatedAt > $1.updatedAt }
            } catch {
                logger.error("Failed to decode document index: \(error.localizedDescription)")
                documents = []
            }
        }
    }
    
    private func persistIndex() {
        let index = Index(documents: documents.sorted { $0.updatedAt > $1.updatedAt },
                          totalSize: documents.reduce(0) { $0 + $1.fileSize })
        do {
            let data = try encoder.encode(index)
            try data.write(to: indexURL, options: [.atomic])
        } catch {
            logger.error("Failed to persist document index: \(error.localizedDescription)")
        }
    }
    
    private func reclaimSpaceIfNeeded(for additionalBytes: Int64) throws {
        let currentUsage = documents.reduce(0) { $0 + $1.fileSize }
        guard currentUsage + additionalBytes > maxDiskUsage else { return }
        var mutableDocuments = documents.sorted { $0.updatedAt < $1.updatedAt }
        var bytesToFree = (currentUsage + additionalBytes) - maxDiskUsage
        var removedIdentifiers: Set<UUID> = []
        while bytesToFree > 0, !mutableDocuments.isEmpty {
            let document = mutableDocuments.removeFirst()
            bytesToFree -= document.fileSize
            removedIdentifiers.insert(document.id)
            let fileURL = directoryURL.appendingPathComponent(document.filename)
            try? fileManager.removeItem(at: fileURL)
        }
        guard bytesToFree <= 0 else {
            throw StoreError.diskQuotaExceeded
        }
        documents.removeAll { removedIdentifiers.contains($0.id) }
        persistIndex()
    }
    
    private func encrypt(_ data: Data) throws -> Data {
        do {
            let sealedBox = try AES.GCM.seal(data, using: encryptionKey)
            guard let combined = sealedBox.combined else {
                throw StoreError.encryptionFailure
            }
            return combined
        } catch let error as StoreError {
            throw error
        } catch {
            logger.error("Encryption failed: \(error.localizedDescription)")
            throw StoreError.encryptionFailure
        }
    }
    
    private func decrypt(_ data: Data) throws -> Data {
        do {
            let box = try AES.GCM.SealedBox(combined: data)
            return try AES.GCM.open(box, using: encryptionKey)
        } catch {
            logger.error("Decryption failed: \(error.localizedDescription)")
            throw StoreError.decryptionFailure
        }
    }
    
    private static func sanitizedFilename(_ value: String) -> String {
        let forbiddenCharacters = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        let components = value.components(separatedBy: forbiddenCharacters)
        let sanitized = components.joined(separator: "-")
        let trimmed = sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "Document"
        }
        return String(trimmed.prefix(40))
    }
    
    private static func loadOrCreateKey(at url: URL) -> SymmetricKey {
        if let existing = try? Data(contentsOf: url), !existing.isEmpty {
            return SymmetricKey(data: existing)
        }
        var randomBytes = Data(count: 32)
        let result = randomBytes.withUnsafeMutableBytes { buffer in
            SecRandomCopyBytes(kSecRandomDefault, 32, buffer.baseAddress!)
        }
        guard result == errSecSuccess else {
            fatalError("Unable to generate secure random key")
        }
        try? randomBytes.write(to: url, options: [.completeFileProtectionUnlessOpen])
        return SymmetricKey(data: randomBytes)
    }
}
