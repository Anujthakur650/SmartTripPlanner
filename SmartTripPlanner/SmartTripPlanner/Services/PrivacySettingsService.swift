import Foundation

@MainActor
final class PrivacySettingsService: ObservableObject {
    @Published var analyticsEnabled: Bool {
        didSet { persistIfNeeded() }
    }
    
    @Published var personalizationEnabled: Bool {
        didSet { persistIfNeeded() }
    }
    
    @Published var diagnosticsEnabled: Bool {
        didSet { persistIfNeeded() }
    }
    
    @Published var notificationsEnabled: Bool {
        didSet { persistIfNeeded() }
    }
    
    @Published var locationServicesEnabled: Bool {
        didSet { persistIfNeeded() }
    }
    
    @Published var backgroundRefreshEnabled: Bool {
        didSet { persistIfNeeded() }
    }
    
    private let storageKey = "com.smarttripplanner.privacy.settings"
    private let userDefaults: UserDefaults
    private var isLoading = true
    
    private struct StoredPreferences: Codable {
        var analyticsEnabled: Bool
        var personalizationEnabled: Bool
        var diagnosticsEnabled: Bool
        var notificationsEnabled: Bool
        var locationServicesEnabled: Bool
        var backgroundRefreshEnabled: Bool
    }
    
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        if let data = userDefaults.data(forKey: storageKey),
           let stored = try? JSONDecoder().decode(StoredPreferences.self, from: data) {
            analyticsEnabled = stored.analyticsEnabled
            personalizationEnabled = stored.personalizationEnabled
            diagnosticsEnabled = stored.diagnosticsEnabled
            notificationsEnabled = stored.notificationsEnabled
            locationServicesEnabled = stored.locationServicesEnabled
            backgroundRefreshEnabled = stored.backgroundRefreshEnabled
        } else {
            analyticsEnabled = true
            personalizationEnabled = true
            diagnosticsEnabled = false
            notificationsEnabled = true
            locationServicesEnabled = true
            backgroundRefreshEnabled = true
        }
        isLoading = false
    }
    
    func resetToDefaults() {
        analyticsEnabled = true
        personalizationEnabled = true
        diagnosticsEnabled = false
        notificationsEnabled = true
        locationServicesEnabled = true
        backgroundRefreshEnabled = true
        userDefaults.removeObject(forKey: storageKey)
    }
    
    private func persistIfNeeded() {
        guard !isLoading else { return }
        let preferences = StoredPreferences(
            analyticsEnabled: analyticsEnabled,
            personalizationEnabled: personalizationEnabled,
            diagnosticsEnabled: diagnosticsEnabled,
            notificationsEnabled: notificationsEnabled,
            locationServicesEnabled: locationServicesEnabled,
            backgroundRefreshEnabled: backgroundRefreshEnabled
        )
        guard let data = try? JSONEncoder().encode(preferences) else { return }
        userDefaults.set(data, forKey: storageKey)
    }
}
