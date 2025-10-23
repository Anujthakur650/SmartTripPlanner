import SwiftUI

@main
struct SmartTripPlannerApp: App {
    @StateObject private var container = DependencyContainer()
    @StateObject private var navigationCoordinator = NavigationCoordinator()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(container)
                .environmentObject(navigationCoordinator)
                .environmentObject(container.appEnvironment)
                .environmentObject(container.documentService)
        }
    }
}
