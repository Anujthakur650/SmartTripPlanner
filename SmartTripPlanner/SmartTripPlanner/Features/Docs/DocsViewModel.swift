import Foundation
import Combine

@MainActor
final class DocsViewModel: ObservableObject {
    struct ViewError: Identifiable {
        let id = UUID()
        let title: String
        let message: String
        let suggestion: String?
    }
    
    struct MetadataEditorState: Identifiable {
        enum Mode {
            case create(ScannedDocument)
            case edit(TravelDocument)
        }
        let id = UUID()
        var mode: Mode
        var metadata: TravelDocument.Metadata
        
        var title: String {
            switch mode {
            case .create:
                return "Save Document"
            case .edit:
                return "Edit Document"
            }
        }
    }
    
    @Published private(set) var documents: [TravelDocument] = []
    @Published private(set) var documentURLs: [UUID: URL] = [:]
    @Published var isLoading: Bool = false
    @Published var isScannerPresented: Bool = false
    @Published var alert: ViewError?
    @Published var metadataEditorState: MetadataEditorState?
    @Published var selectedDocument: TravelDocument?
    
    private var documentStore: DocumentStore?
    
    func configure(with container: DependencyContainer) {
        guard documentStore == nil else { return }
        documentStore = container.documentStore
        Task { await loadDocuments() }
    }
    
    func loadDocuments() async {
        guard let documentStore else { return }
        isLoading = true
        do {
            let docs = try await documentStore.documents()
            updateDocuments(docs)
        } catch {
            alert = ViewError(title: "Unable to load documents", message: error.localizedDescription, suggestion: nil)
        }
        isLoading = false
    }
    
    func refreshDocuments() async {
        guard let documentStore else { return }
        isLoading = true
        do {
            let docs = try await documentStore.refresh()
            updateDocuments(docs)
        } catch {
            alert = ViewError(title: "Unable to refresh", message: error.localizedDescription, suggestion: nil)
        }
        isLoading = false
    }
    
    func presentScanner() {
        isScannerPresented = true
    }
    
    func handleScannerResult(_ result: Result<ScannedDocument, Error>) {
        isScannerPresented = false
        switch result {
        case let .success(scan):
            metadataEditorState = MetadataEditorState(mode: .create(scan), metadata: .default(title: scan.suggestedTitle))
        case let .failure(error):
            alert = ViewError(title: "Scan Failed", message: error.localizedDescription, suggestion: nil)
        }
    }
    
    func editMetadata(for document: TravelDocument) {
        metadataEditorState = MetadataEditorState(mode: .edit(document), metadata: document.metadata)
    }
    
    func deleteDocuments(at offsets: IndexSet) {
        guard let documentStore else { return }
        let documentsToDelete = offsets.compactMap { index -> TravelDocument? in
            guard documents.indices.contains(index) else { return nil }
            return documents[index]
        }
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                for document in documentsToDelete {
                    try await documentStore.deleteDocument(document)
                }
                await self.loadDocuments()
            } catch {
                self.alert = ViewError(title: "Delete Failed", message: error.localizedDescription, suggestion: nil)
            }
        }
    }
    
    func performMetadataAction(metadata: TravelDocument.Metadata, state: MetadataEditorState) {
        guard let documentStore else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                switch state.mode {
                case let .create(scan):
                    let document = try await documentStore.addDocument(data: scan.data, metadata: metadata, pageCount: scan.pageCount)
                    self.insertDocument(document, store: documentStore)
                case let .edit(document):
                    let updated = try await documentStore.updateDocument(document, metadata: metadata)
                    self.replaceDocument(updated, store: documentStore)
                }
                self.metadataEditorState = nil
            } catch {
                self.alert = ViewError(title: "Save Failed", message: error.localizedDescription, suggestion: nil)
            }
        }
    }
    
    func url(for document: TravelDocument) -> URL? {
        documentURLs[document.id]
    }
    
    func delete(_ document: TravelDocument) {
        guard let index = documents.firstIndex(where: { $0.id == document.id }) else { return }
        deleteDocuments(at: IndexSet(integer: index))
    }
    
    private func updateDocuments(_ docs: [TravelDocument]) {
        documents = docs
        if let documentStore {
            documentURLs = Dictionary(uniqueKeysWithValues: docs.map { ($0.id, documentStore.url(for: $0)) })
        }
    }
    
    private func insertDocument(_ document: TravelDocument, store: DocumentStore) {
        var updated = documents
        updated.append(document)
        updated.sort { $0.updatedAt > $1.updatedAt }
        documents = updated
        documentURLs[document.id] = store.url(for: document)
    }
    
    private func replaceDocument(_ document: TravelDocument, store: DocumentStore) {
        guard let index = documents.firstIndex(where: { $0.id == document.id }) else { return }
        documents[index] = document
        documents.sort { $0.updatedAt > $1.updatedAt }
        documentURLs[document.id] = store.url(for: document)
    }
}
