import Foundation

struct PackingContext {
    let trip: Trip
    let weather: WeatherReport
    
    var durationInDays: Int {
        max(trip.durationInDays, 1)
    }
    
    var averageHigh: Double {
        weather.averageHighTemperature
    }
    
    var averageLow: Double {
        weather.averageLowTemperature
    }
    
    var precipitationChance: Double {
        weather.highestPrecipitationChance
    }
    
    var isAdventure: Bool {
        trip.tripType == .adventure || trip.activities.contains(.hiking) || trip.activities.contains(.cycling)
    }
    
    var isBusiness: Bool {
        trip.tripType == .business || trip.activities.contains(.conference)
    }
    
    var isFamily: Bool {
        trip.tripType == .family || trip.activities.contains(.kidsActivities)
    }
    
    var includesBeachTime: Bool {
        trip.tripType == .beach || trip.activities.contains(.swimming) || trip.activities.contains(.watersports)
    }
    
    var includesSkiing: Bool {
        trip.tripType == .ski || trip.activities.contains(.skiing)
    }
    
    var includesNightlife: Bool {
        trip.activities.contains(.nightlife)
    }
    
    var includesFoodTour: Bool {
        trip.activities.contains(.foodTour)
    }
    
    var includesHiking: Bool {
        trip.activities.contains(.hiking)
    }
    
    var includesWellness: Bool {
        trip.activities.contains(.wellness)
    }
}

typealias PackingRulePredicate = (PackingContext) -> Bool
typealias PackingRuleBuilder = (PackingContext) -> [PackingItemTemplate]

struct PackingRule {
    let id: String
    let predicate: PackingRulePredicate
    let builder: PackingRuleBuilder
    
    init(id: String,
         predicate: @escaping PackingRulePredicate,
         builder: @escaping PackingRuleBuilder) {
        self.id = id
        self.predicate = predicate
        self.builder = builder
    }
    
    static func simple(id: String,
                       predicate: @escaping PackingRulePredicate,
                       items: [PackingItemTemplate]) -> PackingRule {
        PackingRule(id: id, predicate: predicate) { _ in items }
    }
}

struct PackingListGenerator {
    private let rules: [PackingRule]
    private let baseTemplates: [PackingItemTemplate]
    
    init(rules: [PackingRule] = PackingListGenerator.defaultRules,
         baseTemplates: [PackingItemTemplate] = PackingListGenerator.baseTemplates) {
        self.rules = rules
        self.baseTemplates = baseTemplates
    }
    
    func generate(for context: PackingContext) -> [PackingListItem] {
        var items = Dictionary(uniqueKeysWithValues: baseTemplates.map { template in
            (template.nameKey, template.makeItem(origin: .base))
        })
        
        for rule in rules where rule.predicate(context) {
            let generatedTemplates = rule.builder(context)
            for template in generatedTemplates {
                let key = template.nameKey
                let newItem = template.makeItem(origin: .rule(rule.id))
                if var existing = items[key] {
                    existing.quantity = max(existing.quantity, newItem.quantity)
                    existing.origin = existing.origin == .base ? newItem.origin : existing.origin
                    items[key] = existing
                } else {
                    items[key] = newItem
                }
            }
        }
        
        let sorted = items.values.sorted(by: PackingListItem.sorter)
        return sorted
    }
}

private extension PackingItemTemplate {
    var nameKey: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
    
    func makeItem(origin: PackingListItem.Origin) -> PackingListItem {
        PackingListItem(name: name,
                        category: category,
                        quantity: quantity,
                        origin: origin)
    }
}

extension PackingListGenerator {
    static let baseTemplates: [PackingItemTemplate] = [
        PackingItemTemplate(name: "Passport", category: .documents),
        PackingItemTemplate(name: "Wallet", category: .essentials),
        PackingItemTemplate(name: "Phone", category: .technology),
        PackingItemTemplate(name: "Phone Charger", category: .technology),
        PackingItemTemplate(name: "Travel Adapter", category: .technology),
        PackingItemTemplate(name: "Medications", category: .health),
        PackingItemTemplate(name: "Toothbrush", category: .toiletries),
        PackingItemTemplate(name: "Toothpaste", category: .toiletries),
        PackingItemTemplate(name: "Reusable Water Bottle", category: .essentials),
        PackingItemTemplate(name: "Socks", category: .clothing, quantity: 3),
        PackingItemTemplate(name: "Underwear", category: .clothing, quantity: 3),
    ]
    
    static let defaultRules: [PackingRule] = [
        PackingRule(id: "duration-clothing", predicate: { $0.durationInDays > 2 }) { context in
            let tops = max(context.durationInDays, 3)
            let bottoms = max(context.durationInDays / 2, 2)
            let sleepwear = max(context.durationInDays / 3, 1)
            return [
                PackingItemTemplate(name: "T-Shirts", category: .clothing, quantity: tops),
                PackingItemTemplate(name: "Casual Bottoms", category: .clothing, quantity: bottoms),
                PackingItemTemplate(name: "Sleepwear", category: .clothing, quantity: sleepwear),
                PackingItemTemplate(name: "Laundry Bag", category: .essentials)
            ]
        },
        
        PackingRule(id: "rain", predicate: { $0.weather.isLikelyRainy }) { _ in
            [
                PackingItemTemplate(name: "Umbrella", category: .essentials),
                PackingItemTemplate(name: "Rain Jacket", category: .clothing),
                PackingItemTemplate(name: "Waterproof Footwear", category: .clothing)
            ]
        },
        
        PackingRule(id: "cold", predicate: { $0.weather.isCold }) { context in
            let thermalLayers = max(context.durationInDays / 2, 2)
            return [
                PackingItemTemplate(name: "Warm Coat", category: .clothing),
                PackingItemTemplate(name: "Thermal Layers", category: .clothing, quantity: thermalLayers),
                PackingItemTemplate(name: "Gloves", category: .clothing),
                PackingItemTemplate(name: "Beanie", category: .clothing)
            ]
        },
        
        PackingRule(id: "hot", predicate: { $0.weather.isHot }) { context in
            [
                PackingItemTemplate(name: "Sun Hat", category: .outdoor),
                PackingItemTemplate(name: "Sunscreen", category: .health),
                PackingItemTemplate(name: "After Sun Lotion", category: .health),
                PackingItemTemplate(name: "Breathable Tops", category: .clothing, quantity: max(context.durationInDays, 3))
            ]
        },
        
        PackingRule(id: "adventure", predicate: { $0.isAdventure }) { _ in
            [
                PackingItemTemplate(name: "Hiking Boots", category: .outdoor),
                PackingItemTemplate(name: "Trail Snacks", category: .essentials),
                PackingItemTemplate(name: "First Aid Kit", category: .health),
                PackingItemTemplate(name: "Reusable Utensils", category: .essentials)
            ]
        },
        
        PackingRule(id: "business", predicate: { $0.isBusiness }) { _ in
            [
                PackingItemTemplate(name: "Blazer", category: .clothing),
                PackingItemTemplate(name: "Dress Shoes", category: .clothing),
                PackingItemTemplate(name: "Laptop", category: .technology),
                PackingItemTemplate(name: "Notebook", category: .documents)
            ]
        },
        
        PackingRule(id: "family", predicate: { $0.isFamily }) { context in
            let snacks = max(context.durationInDays / 2, 2)
            return [
                PackingItemTemplate(name: "Kids Activities", category: .entertainment),
                PackingItemTemplate(name: "Snacks", category: .essentials, quantity: snacks),
                PackingItemTemplate(name: "Wipes", category: .health)
            ]
        },
        
        PackingRule(id: "beach", predicate: { $0.includesBeachTime }) { _ in
            [
                PackingItemTemplate(name: "Swimsuit", category: .clothing),
                PackingItemTemplate(name: "Beach Towel", category: .outdoor),
                PackingItemTemplate(name: "Flip Flops", category: .clothing),
                PackingItemTemplate(name: "Waterproof Phone Case", category: .technology)
            ]
        },
        
        PackingRule(id: "ski", predicate: { $0.includesSkiing || $0.weather.isLikelySnowy }) { _ in
            [
                PackingItemTemplate(name: "Ski Jacket", category: .clothing),
                PackingItemTemplate(name: "Ski Pants", category: .clothing),
                PackingItemTemplate(name: "Goggles", category: .outdoor),
                PackingItemTemplate(name: "Hand Warmers", category: .health)
            ]
        },
        
        PackingRule(id: "nightlife", predicate: { $0.includesNightlife }) { _ in
            [
                PackingItemTemplate(name: "Evening Outfit", category: .clothing),
                PackingItemTemplate(name: "Comfortable Shoes", category: .clothing),
                PackingItemTemplate(name: "Compact Bag", category: .essentials)
            ]
        },
        
        PackingRule(id: "food", predicate: { $0.includesFoodTour }) { _ in
            [
                PackingItemTemplate(name: "Elastic Waist Clothing", category: .clothing),
                PackingItemTemplate(name: "Digestive Relief", category: .health),
                PackingItemTemplate(name: "Sanitizing Wipes", category: .health)
            ]
        },
        
        PackingRule(id: "wellness", predicate: { $0.includesWellness }) { _ in
            [
                PackingItemTemplate(name: "Workout Gear", category: .clothing),
                PackingItemTemplate(name: "Reusable Water Bottle", category: .essentials),
                PackingItemTemplate(name: "Yoga Mat", category: .outdoor)
            ]
        }
    ]
}
