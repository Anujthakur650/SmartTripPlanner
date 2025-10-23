import SwiftUI

struct ContentView: View {
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @EnvironmentObject var theme: AppEnvironment
    
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
        .accentColor(theme.theme.primaryColor)
    }
}

#Preview {
    ContentView()
        .environmentObject(DependencyContainer())
        .environmentObject(NavigationCoordinator())
        .environmentObject(AppEnvironment())
}
