import SwiftUI
import Core
import Services
import Features

public struct AppShellView: View {
    private let registry: ServiceRegistry
    @StateObject private var navigation = NavigationCoordinator()

    public init(registry: ServiceRegistry) {
        self.registry = registry
    }

    public var body: some View {
        TabView(selection: $navigation.selected) {
            TripsDashboard(registry: registry)
                .tag(NavigationDestination.trips)
                .tabItem {
                    Label("Trips", systemImage: "suitcase")
                }
        }
    }
}
