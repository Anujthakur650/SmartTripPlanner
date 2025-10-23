import SwiftUI

struct PackingView: View {
    @EnvironmentObject var container: DependencyContainer
    @State private var packingItems: [PackingItem] = []
    
    var body: some View {
        NavigationStack {
            List {
                if packingItems.isEmpty {
                    ContentUnavailableView(
                        "No Packing Lists",
                        systemImage: "checkmark.circle",
                        description: Text("Create your first packing list")
                    )
                } else {
                    ForEach($packingItems) { $item in
                        HStack {
                            Button(action: { item.isChecked.toggle() }) {
                                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(item.isChecked ? .green : .gray)
                            }
                            .buttonStyle(.plain)
                            
                            Text(item.name)
                                .strikethrough(item.isChecked)
                        }
                    }
                    .onDelete(perform: deleteItems)
                }
            }
            .navigationTitle("Packing")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: addItem) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
    
    private func addItem() {
        packingItems.append(PackingItem(id: UUID(), name: "New Item", isChecked: false))
    }
    
    private func deleteItems(at offsets: IndexSet) {
        packingItems.remove(atOffsets: offsets)
    }
}

struct PackingItem: Identifiable {
    let id: UUID
    var name: String
    var isChecked: Bool
}

#Preview {
    PackingView()
        .environmentObject(DependencyContainer())
        .environmentObject(AppEnvironment())
}
