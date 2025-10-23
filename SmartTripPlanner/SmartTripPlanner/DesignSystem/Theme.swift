import SwiftUI

struct Theme {
    var primaryColor: Color = .blue
    var secondaryColor: Color = .orange
    var backgroundColor: Color = Color(.systemBackground)
    var cardBackgroundColor: Color = Color(.secondarySystemBackground)
    var textPrimaryColor: Color = Color(.label)
    var textSecondaryColor: Color = Color(.secondaryLabel)
    
    var cornerRadius: CGFloat = 12
    var shadowRadius: CGFloat = 5
    var spacing: CGFloat = 16
    
    static let light = Theme(
        primaryColor: .blue,
        secondaryColor: .orange,
        backgroundColor: Color(.systemBackground),
        cardBackgroundColor: Color(.secondarySystemBackground)
    )
    
    static let dark = Theme(
        primaryColor: .blue,
        secondaryColor: .orange,
        backgroundColor: Color(.systemBackground),
        cardBackgroundColor: Color(.secondarySystemBackground)
    )
}

extension View {
    func cardStyle(theme: Theme) -> some View {
        self
            .background(theme.cardBackgroundColor)
            .cornerRadius(theme.cornerRadius)
            .shadow(radius: theme.shadowRadius)
    }
}
