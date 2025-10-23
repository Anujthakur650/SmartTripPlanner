import SwiftUI
import SwiftData

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
                .environmentObject(container.dataController)
        }
        .modelContainer(container.dataController.container)
    }
}
