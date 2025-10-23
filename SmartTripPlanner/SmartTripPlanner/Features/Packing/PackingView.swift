import SwiftUI

struct PackingView: View {
    @EnvironmentObject var dataStore: TravelDataStore
    
    var body: some View {
        NavigationStack {
            List {
                if dataStore.packingItems.isEmpty {
                    ContentUnavailableView(
                        String(localized: "No Packing Lists"),
                        systemImage: "checkmark.circle",
                        description: Text(String(localized: "Create your first packing list"))
                    )
                } else {
                    ForEach(dataStore.packingItems) { item in
                        HStack {
                            Button(action: { dataStore.togglePackingItem(item) }) {
                                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(item.isChecked ? .green : .gray)
                            }
                            .buttonStyle(.plain)
                            
                            Text(item.name)
                                .strikethrough(item.isChecked)
                                .foregroundColor(item.isChecked ? .secondary : .primary)
                        }
                    }
                    .onDelete(perform: deleteItems)
                }
            }
            .navigationTitle(String(localized: "Packing"))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: addItem) {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(String(localized: "Add packing item"))
                }
            }
        }
    }
    
    private func addItem() {
        dataStore.addPackingItem()
    }
    
    private func deleteItems(at offsets: IndexSet) {
        dataStore.deletePackingItems(at: offsets)
    }
}

#Preview {
    PackingView()
        .environmentObject(DependencyContainer())
        .environmentObject(AppEnvironment())
        .environmentObject(TravelDataStore())
}
