import Foundation

final class DocumentStore: ObservableObject {
    @Published private(set) var documents: [TravelDocument] = []
    
    private let storageURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let fileManager: FileManager
    
    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let directory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory
        storageURL = directory.appendingPathComponent("travel-documents.json")
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder = JSONDecoder()
        loadDocuments()
    }
    
    func add(_ document: TravelDocument) {
        documents.append(document)
        persistDocuments()
    }
    
    func remove(_ document: TravelDocument) {
        documents.removeAll { $0.id == document.id }
        persistDocuments()
    }
    
    func reload() {
        loadDocuments()
    }
    
    private func loadDocuments() {
        guard fileManager.fileExists(atPath: storageURL.path), let data = try? Data(contentsOf: storageURL) else {
            documents = []
            return
        }
        if let decoded = try? decoder.decode([TravelDocument].self, from: data) {
            documents = decoded
        }
    }
    
    private func persistDocuments() {
        guard let data = try? encoder.encode(documents) else { return }
        try? data.write(to: storageURL, options: [.atomic])
    }
}
