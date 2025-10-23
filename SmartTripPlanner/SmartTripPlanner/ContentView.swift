import SwiftUI

struct ContentView: View {
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @EnvironmentObject var theme: AppEnvironment
    
    var body: some View {
        TabView(selection: $navigationCoordinator.selectedTab) {
            TripsView()
                .tabItem {
                    Label(String(localized: "Trips"), systemImage: "suitcase.fill")
                }
                .tag(NavigationTab.trips)
            
            PlannerView()
                .tabItem {
                    Label(String(localized: "Planner"), systemImage: "calendar")
                }
                .tag(NavigationTab.planner)
            
            MapView()
                .tabItem {
                    Label(String(localized: "Map"), systemImage: "map.fill")
                }
                .tag(NavigationTab.map)
            
            PackingView()
                .tabItem {
                    Label(String(localized: "Packing"), systemImage: "checkmark.circle.fill")
                }
                .tag(NavigationTab.packing)
            
            DocsView()
                .tabItem {
                    Label(String(localized: "Docs"), systemImage: "folder.fill")
                }
                .tag(NavigationTab.docs)
            
            ExportsView()
                .tabItem {
                    Label(String(localized: "Exports"), systemImage: "square.and.arrow.up")
                }
                .tag(NavigationTab.exports)
            
            SettingsView()
                .tabItem {
                    Label(String(localized: "Settings"), systemImage: "gear")
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
