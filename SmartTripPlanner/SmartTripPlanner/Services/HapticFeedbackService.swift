import Foundation
#if canImport(UIKit)
import UIKit
#endif

protocol HapticFeedbackProviding {
    func success()
    func warning()
    func error()
}

final class HapticFeedbackService: HapticFeedbackProviding {
    func success() {
        notify(.success)
    }
    
    func warning() {
        notify(.warning)
    }
    
    func error() {
        notify(.error)
    }
    
    private func notify(_ type: HapticType) {
        #if canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        switch type {
        case .success:
            generator.notificationOccurred(.success)
        case .warning:
            generator.notificationOccurred(.warning)
        case .error:
            generator.notificationOccurred(.error)
        }
        #endif
    }
    
    private enum HapticType {
        case success
        case warning
        case error
    }
}
