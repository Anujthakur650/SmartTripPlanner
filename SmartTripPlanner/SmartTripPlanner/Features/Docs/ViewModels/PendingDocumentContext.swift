import Foundation

struct PendingDocumentContext: Identifiable {
    enum Source {
        case imported(URL)
        case scanned(DocumentScannerResult)
    }
    
    let id = UUID()
    let source: Source
    var title: String
    var tripName: String
    var tags: [String]
    
    init(source: Source, title: String, tripName: String = "", tags: [String] = []) {
        self.source = source
        self.title = title
        self.tripName = tripName
        self.tags = tags
    }
}
