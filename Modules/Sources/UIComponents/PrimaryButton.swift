import Foundation
import SwiftUI
import Core

public struct PrimaryButtonStyle: ButtonStyle {
    private let theme: Theme

    public init(theme: Theme = .default) {
        self.theme = theme
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .background(Color(theme.primaryColor.semantic.rawValue))
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}
