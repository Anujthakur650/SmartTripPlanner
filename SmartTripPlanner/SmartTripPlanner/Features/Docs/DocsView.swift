import SwiftUI

struct DocsView: View {
    @EnvironmentObject var container: DependencyContainer
    @State private var documents: [TravelDocument] = []
    
    var body: some View {
        NavigationStack {
            List {
                if documents.isEmpty {
                    ContentUnavailableView(
                        "No Documents",
                        systemImage: "folder",
                        description: Text("Add travel documents like passports, tickets, and reservations")
                    )
                } else {
                    ForEach(documents) { document in
                        DocumentRow(document: document)
                    }
                    .onDelete(perform: deleteDocuments)
                }
            }
            .navigationTitle("Documents")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: addDocument) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
    
    private func addDocument() {
        documents.append(TravelDocument(id: UUID(), name: "New Document", type: .other))
    }
    
    private func deleteDocuments(at offsets: IndexSet) {
        documents.remove(atOffsets: offsets)
    }
}

struct TravelDocument: Identifiable, Codable {
    let id: UUID
    var name: String
    var type: DocumentType
    
    enum DocumentType: String, Codable, CaseIterable {
        case passport
        case ticket
        case reservation
        case insurance
        case other
        
        var icon: String {
            switch self {
            case .passport: return "person.text.rectangle"
            case .ticket: return "ticket"
            case .reservation: return "calendar.badge.clock"
            case .insurance: return "shield.fill"
            case .other: return "doc"
            }
        }
    }
}

struct DocumentRow: View {
    let document: TravelDocument
    @EnvironmentObject var theme: AppEnvironment
    
    var body: some View {
        HStack {
            Image(systemName: document.type.icon)
                .foregroundColor(theme.theme.primaryColor)
                .frame(width: 30)
            
            Text(document.name)
        }
    }
}

#Preview {
    DocsView()
        .environmentObject(DependencyContainer())
        .environmentObject(AppEnvironment())
}
