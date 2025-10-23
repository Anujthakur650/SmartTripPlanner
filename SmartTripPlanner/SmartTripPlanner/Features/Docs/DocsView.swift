import SwiftUI

struct DocsView: View {
    @EnvironmentObject var dataStore: TravelDataStore
    
    var body: some View {
        NavigationStack {
            List {
                if dataStore.documents.isEmpty {
                    ContentUnavailableView(
                        String(localized: "No Documents"),
                        systemImage: "folder",
                        description: Text(String(localized: "Add travel documents like passports, tickets, and reservations"))
                    )
                } else {
                    ForEach(dataStore.documents) { document in
                        DocumentRow(document: document)
                    }
                    .onDelete(perform: deleteDocuments)
                }
            }
            .navigationTitle(String(localized: "Documents"))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: addDocument) {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(String(localized: "Add document"))
                }
            }
        }
    }
    
    private func addDocument() {
        dataStore.addDocument()
    }
    
    private func deleteDocuments(at offsets: IndexSet) {
        dataStore.deleteDocuments(at: offsets)
    }
}

struct DocumentRow: View {
    let document: TravelDocument
    @EnvironmentObject var theme: AppEnvironment
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: document.type.systemImage)
                .foregroundColor(theme.theme.primaryColor)
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(document.name)
                    .font(.body)
                Text(document.type.localizedTitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    DocsView()
        .environmentObject(DependencyContainer())
        .environmentObject(AppEnvironment())
        .environmentObject(TravelDataStore())
}
