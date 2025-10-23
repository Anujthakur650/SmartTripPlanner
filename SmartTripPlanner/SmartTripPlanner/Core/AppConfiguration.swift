import Foundation

struct AppConfiguration {
    struct Keys {
        var weatherKitKeyId: String
        var weatherKitTeamId: String
        var weatherKitServiceId: String
        var googleClientId: String
        var googleReversedClientId: String
        var primaryCloudKitContainer: String
        var sharedCloudKitContainer: String
        var servicesCloudKitContainer: String
    }

    static let shared = AppConfiguration()

    let environmentName: String
    let keys: Keys

    private init() {
        environmentName = Bundle.main.object(forInfoDictionaryKey: "ENVIRONMENT_NAME") as? String ?? "Debug"
        keys = Self.loadSecrets()
    }

    private static func loadSecrets() -> Keys {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist") else {
            return Keys(
                weatherKitKeyId: "",
                weatherKitTeamId: "",
                weatherKitServiceId: "",
                googleClientId: "",
                googleReversedClientId: "",
                primaryCloudKitContainer: "iCloud.com.smarttripplanner.core",
                sharedCloudKitContainer: "iCloud.com.smarttripplanner.shared",
                servicesCloudKitContainer: "iCloud.com.smarttripplanner.services"
            )
        }

        guard let data = try? Data(contentsOf: url) else {
            return Keys(
                weatherKitKeyId: "",
                weatherKitTeamId: "",
                weatherKitServiceId: "",
                googleClientId: "",
                googleReversedClientId: "",
                primaryCloudKitContainer: "iCloud.com.smarttripplanner.core",
                sharedCloudKitContainer: "iCloud.com.smarttripplanner.shared",
                servicesCloudKitContainer: "iCloud.com.smarttripplanner.services"
            )
        }

        do {
            if let dictionary = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] {
                return Keys(
                    weatherKitKeyId: dictionary["WEATHERKIT_KEY_ID"] as? String ?? "",
                    weatherKitTeamId: dictionary["WEATHERKIT_TEAM_ID"] as? String ?? "",
                    weatherKitServiceId: dictionary["WEATHERKIT_SERVICE_ID"] as? String ?? "",
                    googleClientId: dictionary["GOOGLE_OAUTH_CLIENT_ID"] as? String ?? "",
                    googleReversedClientId: dictionary["GOOGLE_OAUTH_REVERSED_CLIENT_ID"] as? String ?? "",
                    primaryCloudKitContainer: dictionary["ICLOUD_PRIMARY_CONTAINER"] as? String ?? "iCloud.com.smarttripplanner.core",
                    sharedCloudKitContainer: dictionary["ICLOUD_SHARED_CONTAINER"] as? String ?? "iCloud.com.smarttripplanner.shared",
                    servicesCloudKitContainer: dictionary["ICLOUD_SERVICES_CONTAINER"] as? String ?? "iCloud.com.smarttripplanner.services"
                )
            }
        } catch {
            print("Failed to decode Secrets.plist: \(error)")
        }

        return Keys(
            weatherKitKeyId: "",
            weatherKitTeamId: "",
            weatherKitServiceId: "",
            googleClientId: "",
            googleReversedClientId: "",
            primaryCloudKitContainer: "iCloud.com.smarttripplanner.core",
            sharedCloudKitContainer: "iCloud.com.smarttripplanner.shared",
            servicesCloudKitContainer: "iCloud.com.smarttripplanner.services"
        )
    }
}
