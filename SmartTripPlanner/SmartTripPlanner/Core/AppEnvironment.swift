import Foundation
import SwiftUI

@MainActor
class AppEnvironment: ObservableObject {
    @Published var theme: Theme
    @Published var isOnline: Bool = true
    @Published var isSyncing: Bool = false
    
    init(theme: Theme = .minimalCalm) {
        self.theme = theme
    }
    
    func setTheme(_ theme: Theme) {
        self.theme = theme
    }
}
