import Foundation

enum PackingCategory: Hashable, Identifiable, Codable {
    case essentials
    case clothing
    case toiletries
    case technology
    case outdoor
    case health
    case documents
    case kids
    case entertainment
    case custom(String)
    
    var id: String {
        switch self {
        case .custom(let name):
            return "custom-\(name.lowercased())"
        default:
            return displayName.lowercased()
        }
    }
    
    var displayName: String {
        switch self {
        case .essentials: return "Essentials"
        case .clothing: return "Clothing"
        case .toiletries: return "Toiletries"
        case .technology: return "Technology"
        case .outdoor: return "Outdoor"
        case .health: return "Health"
        case .documents: return "Documents"
        case .kids: return "Kids"
        case .entertainment: return "Entertainment"
        case .custom(let name): return name
        }
    }
    
    var isCustom: Bool {
        if case .custom = self { return true } else { return false }
    }
    
    static var standardCategories: [PackingCategory] {
        [.essentials, .clothing, .toiletries, .technology, .outdoor, .health, .documents, .kids, .entertainment]
    }
    
    func normalizedName() -> String {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
    
    private enum CodingKeys: String, CodingKey {
        case type
        case value
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .custom(let value):
            try container.encode("custom", forKey: .type)
            try container.encode(value, forKey: .value)
        case .essentials:
            try container.encode("essentials", forKey: .type)
        case .clothing:
            try container.encode("clothing", forKey: .type)
        case .toiletries:
            try container.encode("toiletries", forKey: .type)
        case .technology:
            try container.encode("technology", forKey: .type)
        case .outdoor:
            try container.encode("outdoor", forKey: .type)
        case .health:
            try container.encode("health", forKey: .type)
        case .documents:
            try container.encode("documents", forKey: .type)
        case .kids:
            try container.encode("kids", forKey: .type)
        case .entertainment:
            try container.encode("entertainment", forKey: .type)
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "custom":
            let value = try container.decode(String.self, forKey: .value)
            self = .custom(value)
        case "essentials":
            self = .essentials
        case "clothing":
            self = .clothing
        case "toiletries":
            self = .toiletries
        case "technology":
            self = .technology
        case "outdoor":
            self = .outdoor
        case "health":
            self = .health
        case "documents":
            self = .documents
        case "kids":
            self = .kids
        case "entertainment":
            self = .entertainment
        default:
            self = .custom(type.capitalized)
        }
    }
}

struct PackingItemTemplate: Hashable {
    var name: String
    var category: PackingCategory
    var quantity: Int
    
    init(name: String, category: PackingCategory, quantity: Int = 1) {
        self.name = name
        self.category = category
        self.quantity = max(quantity, 1)
    }
}

struct PackingListItem: Identifiable, Codable, Equatable {
    enum Origin: Codable, Equatable {
        case base
        case rule(String)
        case manual
        
        var identifier: String {
            switch self {
            case .base: return "base"
            case .rule(let id): return "rule-\(id)"
            case .manual: return "manual"
            }
        }
        
        var isManual: Bool {
            if case .manual = self { return true } else { return false }
        }
    }
    
    let id: UUID
    var name: String
    var category: PackingCategory
    var quantity: Int
    var isPacked: Bool
    var notes: String?
    var origin: Origin
    var lastModified: Date
    
    init(id: UUID = UUID(),
         name: String,
         category: PackingCategory,
         quantity: Int = 1,
         isPacked: Bool = false,
         notes: String? = nil,
         origin: Origin,
         lastModified: Date = Date()) {
        self.id = id
        self.name = name
        self.category = category
        self.quantity = max(quantity, 1)
        self.isPacked = isPacked
        self.notes = notes
        self.origin = origin
        self.lastModified = lastModified
    }
    
    var normalizedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

struct TripPackingList: Codable, Equatable {
    var tripId: UUID
    var generatedAt: Date
    var weatherDigest: WeatherDigest?
    private(set) var items: [PackingListItem]
    private(set) var customCategories: Set<String>
    
    init(tripId: UUID,
         generatedAt: Date = Date(),
         weatherDigest: WeatherDigest? = nil,
         items: [PackingListItem] = [],
         customCategories: Set<String> = []) {
        self.tripId = tripId
        self.generatedAt = generatedAt
        self.weatherDigest = weatherDigest
        self.items = items
        self.customCategories = customCategories
        sortItems()
    }
    
    var allCategories: [PackingCategory] {
        let custom = customCategories.map { PackingCategory.custom($0) }
        let combined = PackingCategory.standardCategories + custom
        let deduped = Array(Set(combined))
        return deduped.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }
    
    func itemsGroupedByCategory() -> [(PackingCategory, [PackingListItem])] {
        let groups = Dictionary(grouping: items) { $0.category.normalizedName() }
        let sortedKeys = groups.keys.sorted()
        return sortedKeys.compactMap { key in
            guard let exemplar = groups[key]?.first else { return nil }
            let category = exemplar.category
            let sortedItems = groups[key]?.sorted(by: PackingListItem.sorter) ?? []
            return (category, sortedItems)
        }
    }
    
    mutating func addItem(_ item: PackingListItem) {
        ensureCustomCategoryIfNeeded(for: item.category)
        items.append(item)
        sortItems()
    }
    
    mutating func addItems(_ newItems: [PackingListItem]) {
        for item in newItems {
            ensureCustomCategoryIfNeeded(for: item.category)
            if let index = items.firstIndex(where: { $0.normalizedName == item.normalizedName }) {
                items[index].quantity = max(items[index].quantity, item.quantity)
                items[index].origin = items[index].origin.isManual ? items[index].origin : item.origin
            } else {
                items.append(item)
            }
        }
        sortItems()
    }
    
    mutating func updateItem(_ item: PackingListItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        ensureCustomCategoryIfNeeded(for: item.category)
        items[index] = item
        items[index].lastModified = Date()
        sortItems()
    }
    
    mutating func removeItem(id: UUID) {
        items.removeAll { $0.id == id }
    }
    
    mutating func togglePacked(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isPacked.toggle()
        items[index].lastModified = Date()
    }
    
    mutating func regenerate(with generatedItems: [PackingListItem]) {
        let manualItems = items.filter { $0.origin.isManual }
        items = manualItems
        addItems(generatedItems)
        generatedAt = Date()
        sortItems()
    }
    
    mutating func setWeatherDigest(_ digest: WeatherDigest?) {
        weatherDigest = digest
    }
    
    private mutating func ensureCustomCategoryIfNeeded(for category: PackingCategory) {
        if case let .custom(value) = category {
            customCategories.insert(value)
        }
    }
    
    private mutating func sortItems() {
        items.sort(by: PackingListItem.sorter)
    }
}

extension PackingListItem {
    static func sorter(lhs: PackingListItem, rhs: PackingListItem) -> Bool {
        if lhs.category.displayName == rhs.category.displayName {
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
        return lhs.category.displayName.localizedCaseInsensitiveCompare(rhs.category.displayName) == .orderedAscending
    }
}
