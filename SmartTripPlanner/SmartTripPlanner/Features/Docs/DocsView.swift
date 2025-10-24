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
        documents.append(TravelDocument(name: "New Document", type: .custom))
    }
    
    private func deleteDocuments(at offsets: IndexSet) {
        documents.remove(atOffsets: offsets)
    }
}

struct DocumentRow: View {
    let document: TravelDocument
    @EnvironmentObject var theme: AppEnvironment
    
    var body: some View {
        HStack {
            Image(systemName: document.type.iconName)
                .foregroundColor(theme.theme.primaryColor)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(document.name)
                    .font(.body)
                
                if let referenceCode = document.referenceCode, !referenceCode.isEmpty {
                    Text(referenceCode)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    DocsView()
        .environmentObject(DependencyContainer())
        .environmentObject(AppEnvironment())
}
