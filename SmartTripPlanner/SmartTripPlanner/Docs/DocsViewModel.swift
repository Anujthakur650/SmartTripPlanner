import Foundation

@MainActor
final class DocsViewModel: ObservableObject {
    @Published private(set) var documents: [TravelDocument] = []
    @Published private(set) var lastError: Error?
    @Published var isLoading: Bool = false
    
    private let store: DocumentStore
    
    init(store: DocumentStore = DocumentStore()) {
        self.store = store
        documents = store.documents
    }
    
    func refresh() {
        store.reload()
        documents = store.documents
    }
    
    func importDocument(data: Data, metadata: TravelDocumentMetadata, preferredFilename: String? = nil) async {
        isLoading = true
        do {
            _ = try await Task.detached(priority: .userInitiated) {
                try self.store.storeDocument(data: data, metadata: metadata, preferredFilename: preferredFilename)
            }.value
            refresh()
        } catch {
            lastError = error
        }
        isLoading = false
    }
    
    func update(documentId: UUID, mutate: @escaping (inout TravelDocumentMetadata) -> Void) {
        do {
            try store.updateMetadata(for: documentId, transform: mutate)
            refresh()
        } catch {
            lastError = error
        }
    }
    
    func delete(documentId: UUID) {
        do {
            try store.deleteDocument(id: documentId)
            refresh()
        } catch {
            lastError = error
        }
    }
    
    func data(for document: TravelDocument) -> Data? {
        do {
            return try store.data(for: document)
        } catch {
            lastError = error
            return nil
        }
    }
}
