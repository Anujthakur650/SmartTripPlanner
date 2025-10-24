import SwiftUI

struct ContentView: View {
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @EnvironmentObject var theme: AppEnvironment
    
    var body: some View {
        TabView(selection: $navigationCoordinator.selectedTab) {
            TripsView()
                .tabItem {
                    Label(L10n.Tab.trips, systemImage: "suitcase.fill")
                }
                .tag(NavigationTab.trips)
            
            PlannerView()
                .tabItem {
                    Label(L10n.Tab.planner, systemImage: "calendar")
                }
                .tag(NavigationTab.planner)
            
            MapView()
                .tabItem {
                    Label(L10n.Tab.map, systemImage: "map.fill")
                }
                .tag(NavigationTab.map)
            
            PackingView()
                .tabItem {
                    Label(L10n.Tab.packing, systemImage: "checkmark.circle.fill")
                }
                .tag(NavigationTab.packing)
            
            DocsView()
                .tabItem {
                    Label(L10n.Tab.docs, systemImage: "folder.fill")
                }
                .tag(NavigationTab.docs)
            
            SettingsView()
                .tabItem {
                    Label(L10n.Tab.settings, systemImage: "gear")
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
