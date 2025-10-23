import Foundation
import Combine

public enum NavigationDestination: Hashable {
    case trips
    case planner
    case map
    case packing
    case docs
    case settings
}

@MainActor
public final class NavigationCoordinator: ObservableObject {
    @Published public var selected: NavigationDestination

    public init(selected: NavigationDestination = .trips) {
        self.selected = selected
    }

    public func navigate(to destination: NavigationDestination) {
        selected = destination
    }
}
