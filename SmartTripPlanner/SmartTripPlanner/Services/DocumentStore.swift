import Foundation

actor DocumentStore {
    private var storedDocuments: [TravelDocument]
    
    init(documents: [TravelDocument] = []) {
        self.storedDocuments = documents
    }
    
    func documents() async throws -> [TravelDocument] {
        storedDocuments
    }
    
    func addDocument(_ document: TravelDocument) async {
        storedDocuments.append(document)
    }
    
    func removeDocument(withId id: UUID) async {
        storedDocuments.removeAll { $0.id == id }
    }
}
