import Foundation
import UIKit

@MainActor
final class DocumentService: ObservableObject {
    private let storage: DocumentStorageService
    private let metadataExtractor: DocumentMetadataExtractor
    
    @Published private(set) var documents: [DocumentAsset] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var lastError: Error?
    
    init(
        storage: DocumentStorageService = DocumentStorageService(),
        metadataExtractor: DocumentMetadataExtractor = DocumentMetadataExtractor(),
        initialDocuments: [DocumentAsset] = [],
        shouldAutoRefresh: Bool = true
    ) {
        self.storage = storage
        self.metadataExtractor = metadataExtractor
        self.documents = initialDocuments.sorted(by: sortPredicate)
        if shouldAutoRefresh {
            Task {
                await refresh()
            }
        }
    }
    
    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let loaded = try await storage.loadDocuments()
            documents = loaded.sorted(by: sortPredicate)
            lastError = nil
        } catch {
            lastError = error
        }
    }
    
    func documentURL(for document: DocumentAsset) async -> URL {
        await storage.url(for: document.fileName)
    }
    
    func availableTripNames() -> [String] {
        documents.compactMap { $0.tripName }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .uniqued()
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
    
    func addImportedDocument(
        from url: URL,
        title: String?,
        tripName: String?,
        tags: [String]
    ) async throws -> DocumentAsset {
        var securityScoped = url.startAccessingSecurityScopedResource()
        defer {
            if securityScoped {
                url.stopAccessingSecurityScopedResource()
                securityScoped = false
            }
        }
        var storedDescriptor: DocumentStorageService.StoredFileDescriptor?
        do {
            let descriptor = try await storage.storeFile(from: url)
            storedDescriptor = descriptor
            var document = DocumentAsset(
                title: sanitizedTitle(title ?? url.deletingPathExtension().lastPathComponent),
                tripName: sanitizedTripName(tripName),
                fileName: descriptor.fileName,
                kind: descriptor.kind,
                fileSize: descriptor.fileSize,
                tags: sanitize(tags: tags),
                source: .imported
            )
            document.metadata = try await metadata(for: document)
            document.updatedAt = Date()
            document.createdAt = Date()
            documents.append(document)
            documents.sort(by: sortPredicate)
            try await storage.persist(documents: documents)
            lastError = nil
            return document
        } catch {
            if let descriptor = storedDescriptor {
                try? await storage.deleteFile(named: descriptor.fileName)
            }
            lastError = error
            throw error
        }
    }
    
    func addScannedDocument(
        images: [UIImage],
        suggestedTitle: String? = nil,
        tripName: String?,
        tags: [String]
    ) async throws -> DocumentAsset {
        guard !images.isEmpty else {
            throw NSError(domain: "DocumentService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No scan pages available"])
        }
        var storedDescriptor: DocumentStorageService.StoredFileDescriptor?
        do {
            let pdfData = try await Self.composePDF(from: images)
            let descriptor = try await storage.storeData(pdfData, preferredExtension: "pdf")
            storedDescriptor = descriptor
            var document = DocumentAsset(
                title: sanitizedTitle(suggestedTitle ?? "Scanned Document"),
                tripName: sanitizedTripName(tripName),
                fileName: descriptor.fileName,
                kind: .pdf,
                fileSize: descriptor.fileSize,
                tags: sanitize(tags: tags),
                source: .scanned
            )
            document.metadata = try await metadataExtractor.extractMetadata(from: images)
            document.updatedAt = Date()
            document.createdAt = Date()
            documents.append(document)
            documents.sort(by: sortPredicate)
            try await storage.persist(documents: documents)
            lastError = nil
            return document
        } catch {
            if let descriptor = storedDescriptor {
                try? await storage.deleteFile(named: descriptor.fileName)
            }
            lastError = error
            throw error
        }
    }
    
    func delete(_ document: DocumentAsset) async throws {
        guard let index = documents.firstIndex(where: { $0.id == document.id }) else { return }
        let removed = documents.remove(at: index)
        do {
            try await storage.deleteFile(named: document.fileName)
            try await storage.persist(documents: documents)
            lastError = nil
        } catch {
            documents.insert(removed, at: index)
            lastError = error
            throw error
        }
    }
    
    func updateTags(for document: DocumentAsset, tags: [String]) async throws {
        guard let index = documents.firstIndex(where: { $0.id == document.id }) else { return }
        documents[index].tags = Self.sanitize(tags: tags)
        documents[index].updatedAt = Date()
        documents.sort(by: sortPredicate)
        try await storage.persist(documents: documents)
        lastError = nil
    }
    
    func updateTrip(for document: DocumentAsset, tripName: String?) async throws {
        guard let index = documents.firstIndex(where: { $0.id == document.id }) else { return }
        documents[index].tripName = sanitizedTripName(tripName)
        documents[index].updatedAt = Date()
        documents.sort(by: sortPredicate)
        try await storage.persist(documents: documents)
        lastError = nil
    }
    
    func metadata(for document: DocumentAsset) async throws -> DocumentMetadata {
        switch document.kind {
        case .pdf:
            let url = await storage.url(for: document.fileName)
            return try await metadataExtractor.extractMetadata(fromPDFAt: url)
        case .image:
            let url = await storage.url(for: document.fileName)
            guard let image = UIImage(contentsOfFile: url.path) else { return DocumentMetadata() }
            return try await metadataExtractor.extractMetadata(from: [image])
        case .pass, .unknown:
            let url = await storage.url(for: document.fileName)
            let data = (try? Data(contentsOf: url)) ?? Data()
            if let text = String(data: data, encoding: .utf8), !text.isEmpty {
                return metadataExtractor.extractMetadata(fromRawText: text)
            }
            return DocumentMetadata()
        }
    }
    
    func recalculateMetadata(for document: DocumentAsset) async throws {
        guard let index = documents.firstIndex(where: { $0.id == document.id }) else { return }
        let metadata = try await metadata(for: document)
        documents[index].metadata = metadata
        documents[index].updatedAt = Date()
        documents.sort(by: sortPredicate)
        try await storage.persist(documents: documents)
        lastError = nil
    }
    
    private func sanitizedTitle(_ title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Document" : trimmed
    }
    
    private func sanitizedTripName(_ name: String?) -> String? {
        guard let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
    
    private static func sanitize(tags: [String]) -> [String] {
        tags.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .uniqued()
    }
    
    private func sanitize(tags: [String]) -> [String] {
        Self.sanitize(tags: tags)
    }
    
    private func sortPredicate(_ lhs: DocumentAsset, _ rhs: DocumentAsset) -> Bool {
        if lhs.updatedAt != rhs.updatedAt {
            return lhs.updatedAt > rhs.updatedAt
        }
        return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
    }
    
    private static func composePDF(from images: [UIImage]) async throws -> Data {
        try await Task.detached(priority: .userInitiated) {
            guard let first = images.first else {
                throw NSError(domain: "DocumentService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Unable to render PDF"]) }
            let rendererBounds = CGRect(origin: .zero, size: first.size)
            let renderer = UIGraphicsPDFRenderer(bounds: rendererBounds)
            let data = renderer.pdfData { context in
                for image in images {
                    let pageRect = CGRect(origin: .zero, size: image.size)
                    context.beginPage(withBounds: pageRect, pageInfo: [:])
                    image.draw(in: pageRect)
                }
            }
            return data
        }.value
    }
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen: Set<Element> = []
        return filter { seen.insert($0).inserted }
    }
}
