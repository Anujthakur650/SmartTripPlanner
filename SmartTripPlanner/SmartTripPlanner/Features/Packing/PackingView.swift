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
                        HStack(alignment: .top, spacing: 12) {
                            Button(action: { item.isPacked.toggle() }) {
                                Image(systemName: item.isPacked ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(item.isPacked ? .green : .gray)
                            }
                            .buttonStyle(.plain)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.name)
                                    .strikethrough(item.isPacked)
                                    .font(.body)
                                
                                Text(detail(for: item))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
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
        packingItems.append(PackingItem(name: "New Item"))
    }
    
    private func deleteItems(at offsets: IndexSet) {
        packingItems.remove(atOffsets: offsets)
    }
    
    private func detail(for item: PackingItem) -> String {
        var components: [String] = []
        if item.quantity > 1 {
            components.append("Qty \(item.quantity)")
        }
        components.append(item.category.displayName)
        return components.joined(separator: " • ")
    }
}

#Preview {
    PackingView()
        .environmentObject(DependencyContainer())
        .environmentObject(AppEnvironment())
}
