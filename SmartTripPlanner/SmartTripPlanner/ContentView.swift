import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var navigationCoordinator: NavigationCoordinator
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        TabView(selection: $navigationCoordinator.selectedTab) {
            TripsView()
                .tabItem {
                    Label("Trips", systemImage: "suitcase.fill")
                }
                .tag(NavigationTab.trips)
            
            PlannerView()
                .tabItem {
                    Label("Planner", systemImage: "calendar")
                }
                .tag(NavigationTab.planner)
            
            MapView()
                .tabItem {
                    Label("Map", systemImage: "map.fill")
                }
                .tag(NavigationTab.map)
            
            PackingView()
                .tabItem {
                    Label("Packing", systemImage: "checkmark.circle.fill")
                }
                .tag(NavigationTab.packing)
            
            DocsView()
                .tabItem {
                    Label("Docs", systemImage: "folder.fill")
                }
                .tag(NavigationTab.docs)
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(NavigationTab.settings)
        }
        .tint(appEnvironment.theme.colors.primary.resolved(for: colorScheme))
        .background(appEnvironment.theme.colors.background.resolved(for: colorScheme).ignoresSafeArea())
    }
}

#Preview {
    ContentView()
        .environmentObject(DependencyContainer())
        .environmentObject(NavigationCoordinator())
        .environmentObject(AppEnvironment())
}
