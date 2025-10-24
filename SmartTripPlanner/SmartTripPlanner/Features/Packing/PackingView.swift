import SwiftUI

struct PackingView: View {
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @Environment(\.colorScheme) private var colorScheme
    @State private var packingItems: [PackingItem] = PackingItem.sampleData
    
    private var theme: Theme { appEnvironment.theme }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing.l) {
                    SectionHeader(
                        title: "Packing list",
                        caption: "Stay light and ready wherever you land"
                    )
                    if packingItems.isEmpty {
                        EmptyStateView(
                            icon: "bag",
                            title: "Packing starts here",
                            message: "Add essentials, outfits, and gear to stay organised.",
                            actionTitle: "Add an item",
                            action: addItem
                        )
                    } else {
                        Card(style: .standard) {
                            VStack(spacing: theme.spacing.m) {
                                ForEach(packingItems) { item in
                                    PackingRow(item: item) {
                                        toggleItem(item)
                                    }
                                }
                            }
                        }
                        AppButton(title: "Add item", style: .primary, action: addItem)
                    }
                }
                .padding(.horizontal, theme.spacing.l)
                .padding(.vertical, theme.spacing.l)
            }
            .background(theme.colors.background.resolved(for: colorScheme))
            .navigationTitle("Packing")
        }
    }
    
    private func addItem() {
        let item = PackingItem(
            id: UUID(),
            name: "Reusable water bottle",
            category: .gear,
            isPacked: false
        )
        packingItems.append(item)
    }
    
    private func toggleItem(_ item: PackingItem) {
        guard let index = packingItems.firstIndex(where: { $0.id == item.id }) else { return }
        packingItems[index].isPacked.toggle()
    }
}

struct PackingItem: Identifiable {
    let id: UUID
    var name: String
    var category: Category
    var isPacked: Bool
    
    enum Category {
        case clothing
        case tech
        case documents
        case gear
        case wellness
        
        var icon: String {
            switch self {
            case .clothing: return "hanger"
            case .tech: return "headphones"
            case .documents: return "doc.text"
            case .gear: return "backpack"
            case .wellness: return "cross.vial"
            }
        }
        
        var description: String {
            switch self {
            case .clothing: return "Outfits and layers"
            case .tech: return "Cables and devices"
            case .documents: return "IDs and confirmations"
            case .gear: return "Tools and accessories"
            case .wellness: return "Health and comfort"
            }
        }
    }
    
    var statusLabel: String {
        isPacked ? "Packed" : "Pending"
    }
    
    var statusStyle: TagLabel.Style {
        isPacked ? .success : .neutral
    }
    
    static let sampleData: [PackingItem] = [
        PackingItem(id: UUID(), name: "Linen shirt", category: .clothing, isPacked: true),
        PackingItem(id: UUID(), name: "Portable charger", category: .tech, isPacked: false),
        PackingItem(id: UUID(), name: "Passport wallet", category: .documents, isPacked: true),
        PackingItem(id: UUID(), name: "Camera lens", category: .gear, isPacked: false),
        PackingItem(id: UUID(), name: "Travel pillow", category: .wellness, isPacked: false)
    ]
}

private struct PackingRow: View {
    let item: PackingItem
    var onToggle: () -> Void
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ListRow(
            icon: item.category.icon,
            title: item.name,
            subtitle: item.category.description,
            tagText: item.statusLabel,
            tagStyle: item.statusStyle
        ) {
            Button(action: onToggle) {
                Image(systemName: item.isPacked ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.isPacked ? appEnvironment.theme.colors.success.resolved(for: colorScheme) : appEnvironment.theme.colors.textSecondary.resolved(for: colorScheme))
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    PackingView()
        .environmentObject(AppEnvironment())
}
