import Foundation
import SwiftUI

enum NavigationTab: Int, Hashable {
    case trips
    case planner
    case map
    case packing
    case docs
    case exports
    case settings
}

@MainActor
class NavigationCoordinator: ObservableObject {
    @Published var selectedTab: NavigationTab = .trips
    @Published var navigationPath = NavigationPath()
    
    func navigateTo(tab: NavigationTab) {
        selectedTab = tab
    }
    
    func pushToPath<T: Hashable>(_ value: T) {
        navigationPath.append(value)
    }
    
    func popToRoot() {
        navigationPath = NavigationPath()
    }
}
