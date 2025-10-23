import Foundation
import Combine

@MainActor
public final class AppEnvironment: ObservableObject {
    @Published public var theme: Theme
    @Published public var isOnline: Bool
    @Published public var isSyncing: Bool

    public init(theme: Theme = Theme.default, isOnline: Bool = true, isSyncing: Bool = false) {
        self.theme = theme
        self.isOnline = isOnline
        self.isSyncing = isSyncing
    }
}

public struct Theme: Equatable {
    public let primaryColor: ColorToken
    public let secondaryColor: ColorToken
    public let accentColor: ColorToken
    public let backgroundColor: ColorToken

    public init(primaryColor: ColorToken, secondaryColor: ColorToken, accentColor: ColorToken, backgroundColor: ColorToken) {
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
        self.accentColor = accentColor
        self.backgroundColor = backgroundColor
    }

    public static let `default` = Theme(
        primaryColor: .semantic(.primary),
        secondaryColor: .semantic(.secondary),
        accentColor: .semantic(.accent),
        backgroundColor: .semantic(.background)
    )
}

public struct ColorToken: Equatable {
    public enum Semantic: String {
        case primary
        case secondary
        case accent
        case background
        case success
        case warning
        case error
    }

    public let semantic: Semantic

    public init(_ semantic: Semantic) {
        self.semantic = semantic
    }

    public static func semantic(_ semantic: Semantic) -> ColorToken {
        ColorToken(semantic)
    }
}
