import SwiftUI
import MapKit

private struct ThemeResolver {
    let theme: Theme
    let scheme: ColorScheme
    
    func color(_ token: DynamicColor) -> Color {
        token.resolved(for: scheme)
    }
}

private struct ThemeShadowModifier: ViewModifier {
    let token: Theme.ShadowToken
    let scheme: ColorScheme
    
    func body(content: Content) -> some View {
        if token.radius == 0 {
            content
        } else {
            content.shadow(color: token.color(for: scheme), radius: token.radius, x: token.x, y: token.y)
        }
    }
}

struct Card<Content: View>: View {
    enum Style {
        case standard
        case elevated
        case muted
    }
    
    private let title: String?
    private let subtitle: String?
    private let style: Style
    private let content: Content
    
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @Environment(\.colorScheme) private var colorScheme
    
    init(title: String? = nil, subtitle: String? = nil, style: Style = .standard, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.style = style
        self.content = content()
    }
    
    var body: some View {
        let resolver = ThemeResolver(theme: appEnvironment.theme, scheme: colorScheme)
        let spacing = appEnvironment.theme.spacing
        let typography = appEnvironment.theme.typography
        let radii = appEnvironment.theme.radii
        let colors = appEnvironment.theme.colors
        let background: Color
        let border: Color
        let shadow: Theme.ShadowToken
        
        switch style {
        case .standard:
            background = resolver.color(colors.surface)
            border = resolver.color(colors.border)
            shadow = appEnvironment.theme.shadows.subtle
        case .elevated:
            background = resolver.color(colors.surfaceElevated)
            border = resolver.color(colors.surfaceElevated)
            shadow = appEnvironment.theme.shadows.raised
        case .muted:
            background = resolver.color(colors.surfaceMuted)
            border = resolver.color(colors.surfaceMuted)
            shadow = appEnvironment.theme.shadows.none
        }
        
        return VStack(alignment: .leading, spacing: spacing.s) {
            if let title {
                Text(title)
                    .font(typography.title2)
                    .foregroundStyle(resolver.color(colors.textPrimary))
                    .accessibilityAddTraits(.isHeader)
            }
            if let subtitle {
                Text(subtitle)
                    .font(typography.subheadline)
                    .foregroundStyle(resolver.color(colors.textSecondary))
            }
            content
        }
        .padding(spacing.l)
        .background(
            RoundedRectangle(cornerRadius: radii.l, style: .continuous)
                .fill(background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: radii.l, style: .continuous)
                .stroke(border, lineWidth: style == .elevated ? 0 : 1)
        )
        .modifier(ThemeShadowModifier(token: shadow, scheme: colorScheme))
    }
}

struct AppButton: View {
    enum Style {
        case primary
        case secondary
        case tinted
        case ghost
        case destructive
    }
    
    let title: String
    var style: Style = .primary
    var icon: String? = nil
    var fillWidth: Bool = true
    var isLoading: Bool = false
    var isDisabled: Bool = false
    var action: () -> Void
    
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        let resolver = ThemeResolver(theme: appEnvironment.theme, scheme: colorScheme)
        let colors = appEnvironment.theme.colors
        let spacing = appEnvironment.theme.spacing
        let radii = appEnvironment.theme.radii
        let typography = appEnvironment.theme.typography
        let background: Color
        let foreground: Color
        let border: Color?
        
        switch style {
        case .primary:
            background = resolver.color(colors.primary)
            foreground = resolver.color(colors.onPrimary)
            border = nil
        case .secondary:
            background = resolver.color(colors.surface)
            foreground = resolver.color(colors.textPrimary)
            border = resolver.color(colors.border)
        case .tinted:
            background = resolver.color(colors.accent)
            foreground = resolver.color(colors.onAccent)
            border = nil
        case .ghost:
            background = resolver.color(colors.surfaceMuted)
            foreground = resolver.color(colors.textPrimary)
            border = resolver.color(colors.border)
        case .destructive:
            background = resolver.color(colors.error)
            foreground = resolver.color(colors.onError)
            border = nil
        }
        
        return Button(action: action) {
            HStack(spacing: spacing.xs) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(foreground)
                } else if let icon {
                    Image(systemName: icon)
                }
                Text(title)
            }
            .font(typography.button)
            .foregroundStyle(foreground)
            .frame(maxWidth: fillWidth ? .infinity : nil)
            .padding(.vertical, spacing.s)
            .padding(.horizontal, spacing.l)
            .background(
                RoundedRectangle(cornerRadius: radii.m, style: .continuous)
                    .fill(background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radii.m, style: .continuous)
                    .stroke(border ?? .clear, lineWidth: border == nil ? 0 : 1)
            )
            .opacity(isDisabled || isLoading ? 0.7 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
    }
}

struct TagLabel: View {
    enum Style {
        case primary
        case neutral
        case success
        case warning
        case info
        case danger
    }
    
    let text: String
    var style: Style = .neutral
    
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        let resolver = ThemeResolver(theme: appEnvironment.theme, scheme: colorScheme)
        let spacing = appEnvironment.theme.spacing
        let radii = appEnvironment.theme.radii
        let colors = appEnvironment.theme.colors
        let background: Color
        let foreground: Color
        
        switch style {
        case .primary:
            background = resolver.color(colors.primary)
            foreground = resolver.color(colors.onPrimary)
        case .neutral:
            background = resolver.color(colors.surfaceMuted)
            foreground = resolver.color(colors.textPrimary)
        case .success:
            background = resolver.color(colors.success)
            foreground = resolver.color(colors.onSuccess)
        case .warning:
            background = resolver.color(colors.warning)
            foreground = resolver.color(colors.onWarning)
        case .info:
            background = resolver.color(colors.info)
            foreground = resolver.color(colors.onInfo)
        case .danger:
            background = resolver.color(colors.error)
            foreground = resolver.color(colors.onError)
        }
        
        return Text(text)
            .font(appEnvironment.theme.typography.caption.weight(.semibold))
            .foregroundStyle(foreground)
            .padding(.vertical, spacing.xs * 0.75)
            .padding(.horizontal, spacing.s)
            .background(
                Capsule(style: .continuous)
                    .fill(background)
            )
    }
}

struct ListRow<Accessory: View>: View {
    let icon: String?
    let title: String
    var subtitle: String? = nil
    var detail: String? = nil
    var tagText: String? = nil
    var tagStyle: TagLabel.Style? = nil
    @ViewBuilder var accessory: () -> Accessory
    
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @Environment(\.colorScheme) private var colorScheme
    
    init(
        icon: String? = nil,
        title: String,
        subtitle: String? = nil,
        detail: String? = nil,
        tagText: String? = nil,
        tagStyle: TagLabel.Style? = nil,
        @ViewBuilder accessory: @escaping () -> Accessory = { EmptyView() }
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.detail = detail
        self.tagText = tagText
        self.tagStyle = tagStyle
        self.accessory = accessory
    }
    
    var body: some View {
        let resolver = ThemeResolver(theme: appEnvironment.theme, scheme: colorScheme)
        let spacing = appEnvironment.theme.spacing
        let typography = appEnvironment.theme.typography
        let colors = appEnvironment.theme.colors
        let radii = appEnvironment.theme.radii
        
        return HStack(alignment: .center, spacing: spacing.m) {
            if let icon {
                ZStack {
                    Circle()
                        .fill(resolver.color(colors.surfaceMuted))
                        .frame(width: spacing.xxl, height: spacing.xxl)
                    Image(systemName: icon)
                        .font(.headline)
                        .foregroundStyle(resolver.color(colors.primary))
                }
            }
            VStack(alignment: .leading, spacing: spacing.xs) {
                HStack(alignment: .firstTextBaseline, spacing: spacing.xs) {
                    Text(title)
                        .font(typography.body.weight(.semibold))
                        .foregroundStyle(resolver.color(colors.textPrimary))
                    if let tagText, let tagStyle {
                        TagLabel(text: tagText, style: tagStyle)
                            .fixedSize()
                    } else if let detail {
                        Text(detail)
                            .font(typography.caption)
                            .foregroundStyle(resolver.color(colors.textSecondary))
                    }
                }
                if let subtitle {
                    Text(subtitle)
                        .font(typography.subheadline)
                        .foregroundStyle(resolver.color(colors.textSecondary))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: spacing.m)
            accessory()
                .font(typography.subheadline)
                .foregroundStyle(resolver.color(colors.textSecondary))
        }
        .padding(.vertical, spacing.s)
        .padding(.horizontal, spacing.m)
        .background(
            RoundedRectangle(cornerRadius: radii.m, style: .continuous)
                .fill(resolver.color(colors.surface))
        )
        .overlay(
            RoundedRectangle(cornerRadius: radii.m, style: .continuous)
                .stroke(resolver.color(colors.border), lineWidth: 1)
        )
    }
}

struct MapCard: View {
    struct TagInfo: Identifiable {
        let id: String
        let text: String
        let style: TagLabel.Style
        
        init(text: String, style: TagLabel.Style) {
            self.id = text
            self.text = text
            self.style = style
        }
    }
    
    let title: String
    var subtitle: String? = nil
    var coordinate: CLLocationCoordinate2D? = nil
    var footnote: String? = nil
    var tags: [TagInfo] = []
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @Environment(\.colorScheme) private var colorScheme
    @State private var camera: MapCameraPosition = .automatic
    
    var body: some View {
        let resolver = ThemeResolver(theme: appEnvironment.theme, scheme: colorScheme)
        let spacing = appEnvironment.theme.spacing
        let colors = appEnvironment.theme.colors
        let typography = appEnvironment.theme.typography
        
        return Card(style: .elevated) {
            VStack(alignment: .leading, spacing: spacing.m) {
                if let coordinate {
                    let region = MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02))
                    Map(position: Binding(get: { camera }, set: { camera = $0 }), interactionModes: []) {
                        Marker(title, coordinate: coordinate)
                            .tint(resolver.color(colors.primary))
                    }
                    .mapStyle(.standard)
                    .onAppear {
                        camera = .region(region)
                    }
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: appEnvironment.theme.radii.m, style: .continuous))
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: appEnvironment.theme.radii.m, style: .continuous)
                            .fill(resolver.color(colors.surfaceMuted))
                        VStack(spacing: spacing.s) {
                            Image(systemName: "map")
                                .font(.title2)
                                .foregroundStyle(resolver.color(colors.textSecondary))
                            Text("Location unavailable")
                                .font(typography.caption)
                                .foregroundStyle(resolver.color(colors.textSecondary))
                        }
                    }
                    .frame(height: 160)
                }
                VStack(alignment: .leading, spacing: spacing.xs) {
                    Text(title)
                        .font(typography.title2)
                        .foregroundStyle(resolver.color(colors.textPrimary))
                    if let subtitle {
                        Text(subtitle)
                            .font(typography.subheadline)
                            .foregroundStyle(resolver.color(colors.textSecondary))
                    }
                }
                if !tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: spacing.xs) {
                            ForEach(tags) { tag in
                                TagLabel(text: tag.text, style: tag.style)
                            }
                        }
                        .padding(.vertical, spacing.xs)
                    }
                }
                if let footnote {
                    Text(footnote)
                        .font(typography.caption)
                        .foregroundStyle(resolver.color(colors.textSecondary))
                }
                if let actionTitle, let action {
                    AppButton(title: actionTitle, style: .secondary, fillWidth: false, action: action)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct TimelineItem: View {
    enum Status {
        case planned
        case completed
        case inProgress
        case warning
    }
    
    let icon: String?
    let time: String
    let title: String
    var subtitle: String? = nil
    var detail: String? = nil
    var status: Status = .planned
    
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        let resolver = ThemeResolver(theme: appEnvironment.theme, scheme: colorScheme)
        let spacing = appEnvironment.theme.spacing
        let typography = appEnvironment.theme.typography
        let colors = appEnvironment.theme.colors
        let statusColor: Color
        
        switch status {
        case .planned:
            statusColor = resolver.color(colors.info)
        case .completed:
            statusColor = resolver.color(colors.success)
        case .inProgress:
            statusColor = resolver.color(colors.primary)
        case .warning:
            statusColor = resolver.color(colors.warning)
        }
        
        return HStack(alignment: .top, spacing: spacing.m) {
            VStack(spacing: spacing.xs) {
                Text(time)
                    .font(typography.caption)
                    .foregroundStyle(resolver.color(colors.textSecondary))
                Circle()
                    .fill(statusColor)
                    .frame(width: spacing.m, height: spacing.m)
                    .overlay(Circle().stroke(resolver.color(colors.background), lineWidth: 2))
            }
            Rectangle()
                .fill(resolver.color(colors.border))
                .frame(width: 1)
                .padding(.vertical, spacing.xs)
            VStack(alignment: .leading, spacing: spacing.xs) {
                HStack(alignment: .center, spacing: spacing.xs) {
                    if let icon {
                        Image(systemName: icon)
                            .foregroundStyle(statusColor)
                    }
                    Text(title)
                        .font(typography.body.weight(.semibold))
                        .foregroundStyle(resolver.color(colors.textPrimary))
                }
                if let subtitle {
                    Text(subtitle)
                        .font(typography.subheadline)
                        .foregroundStyle(resolver.color(colors.textSecondary))
                }
                if let detail {
                    Text(detail)
                        .font(typography.caption)
                        .foregroundStyle(resolver.color(colors.textSecondary))
                }
            }
            Spacer()
        }
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        let resolver = ThemeResolver(theme: appEnvironment.theme, scheme: colorScheme)
        let spacing = appEnvironment.theme.spacing
        let typography = appEnvironment.theme.typography
        let colors = appEnvironment.theme.colors
        
        return VStack(spacing: spacing.m) {
            Circle()
                .fill(resolver.color(colors.surfaceMuted))
                .frame(width: 96, height: 96)
                .overlay(
                    Image(systemName: icon)
                        .font(.largeTitle)
                        .foregroundStyle(resolver.color(colors.primary))
                )
            VStack(spacing: spacing.xs) {
                Text(title)
                    .font(typography.title2)
                    .foregroundStyle(resolver.color(colors.textPrimary))
                Text(message)
                    .font(typography.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(resolver.color(colors.textSecondary))
            }
            if let actionTitle, let action {
                AppButton(title: actionTitle, style: .primary, action: action)
                    .frame(maxWidth: 240)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(spacing.xl)
    }
}

struct LoadingStateView: View {
    var message: String? = nil
    
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        let resolver = ThemeResolver(theme: appEnvironment.theme, scheme: colorScheme)
        let spacing = appEnvironment.theme.spacing
        let colors = appEnvironment.theme.colors
        let typography = appEnvironment.theme.typography
        
        return HStack(spacing: spacing.m) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(resolver.color(colors.primary))
            if let message {
                Text(message)
                    .font(typography.body)
                    .foregroundStyle(resolver.color(colors.textSecondary))
            }
        }
        .padding(spacing.m)
        .background(
            RoundedRectangle(cornerRadius: appEnvironment.theme.radii.m, style: .continuous)
                .fill(resolver.color(colors.surface))
        )
        .overlay(
            RoundedRectangle(cornerRadius: appEnvironment.theme.radii.m, style: .continuous)
                .stroke(resolver.color(colors.border), lineWidth: 1)
        )
    }
}

struct ErrorSurface: View {
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        let resolver = ThemeResolver(theme: appEnvironment.theme, scheme: colorScheme)
        let spacing = appEnvironment.theme.spacing
        let colors = appEnvironment.theme.colors
        let typography = appEnvironment.theme.typography
        
        return VStack(alignment: .leading, spacing: spacing.s) {
            HStack(spacing: spacing.xs) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(resolver.color(colors.onError))
                Text(title)
                    .font(typography.headline)
                    .foregroundStyle(resolver.color(colors.onError))
            }
            Text(message)
                .font(typography.subheadline)
                .foregroundStyle(resolver.color(colors.onError))
            if let actionTitle, let action {
                AppButton(title: actionTitle, style: .ghost, fillWidth: false, action: action)
            }
        }
        .padding(spacing.l)
        .background(
            RoundedRectangle(cornerRadius: appEnvironment.theme.radii.l, style: .continuous)
                .fill(resolver.color(colors.error))
        )
        .modifier(ThemeShadowModifier(token: appEnvironment.theme.shadows.subtle, scheme: colorScheme))
    }
}

struct FormTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var helper: String? = nil
    var icon: String? = nil
    
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        let resolver = ThemeResolver(theme: appEnvironment.theme, scheme: colorScheme)
        let spacing = appEnvironment.theme.spacing
        let typography = appEnvironment.theme.typography
        let colors = appEnvironment.theme.colors
        let radii = appEnvironment.theme.radii
        
        return VStack(alignment: .leading, spacing: spacing.xs) {
            Text(title)
                .font(typography.subheadline.weight(.semibold))
                .foregroundStyle(resolver.color(colors.textPrimary))
            HStack(spacing: spacing.xs) {
                if let icon {
                    Image(systemName: icon)
                        .foregroundStyle(resolver.color(colors.textSecondary))
                }
                TextField(placeholder, text: $text)
                    .font(typography.body)
                    .foregroundStyle(resolver.color(colors.textPrimary))
            }
            .padding(.vertical, spacing.s)
            .padding(.horizontal, spacing.m)
            .background(
                RoundedRectangle(cornerRadius: radii.m, style: .continuous)
                    .fill(resolver.color(colors.surface))
            )
            .overlay(
                RoundedRectangle(cornerRadius: radii.m, style: .continuous)
                    .stroke(resolver.color(colors.border), lineWidth: 1)
            )
            if let helper {
                Text(helper)
                    .font(typography.caption)
                    .foregroundStyle(resolver.color(colors.textSecondary))
            }
        }
    }
}

struct FormToggleRow: View {
    let title: String
    @Binding var isOn: Bool
    var helper: String? = nil
    
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        let resolver = ThemeResolver(theme: appEnvironment.theme, scheme: colorScheme)
        let spacing = appEnvironment.theme.spacing
        let typography = appEnvironment.theme.typography
        let colors = appEnvironment.theme.colors
        let radii = appEnvironment.theme.radii
        
        return VStack(alignment: .leading, spacing: spacing.xs) {
            Toggle(isOn: $isOn) {
                Text(title)
                    .font(typography.body)
                    .foregroundStyle(resolver.color(colors.textPrimary))
            }
            .tint(resolver.color(colors.primary))
            .padding(.vertical, spacing.s)
            .padding(.horizontal, spacing.m)
            .background(
                RoundedRectangle(cornerRadius: radii.m, style: .continuous)
                    .fill(resolver.color(colors.surface))
            )
            .overlay(
                RoundedRectangle(cornerRadius: radii.m, style: .continuous)
                    .stroke(resolver.color(colors.border), lineWidth: 1)
            )
            if let helper {
                Text(helper)
                    .font(typography.caption)
                    .foregroundStyle(resolver.color(colors.textSecondary))
            }
        }
    }
}

struct SectionHeader: View {
    let title: String
    var caption: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        let resolver = ThemeResolver(theme: appEnvironment.theme, scheme: colorScheme)
        let typography = appEnvironment.theme.typography
        let spacing = appEnvironment.theme.spacing
        let colors = appEnvironment.theme.colors
        
        return HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: spacing.xs) {
                Text(title)
                    .font(typography.title2)
                    .foregroundStyle(resolver.color(colors.textPrimary))
                if let caption {
                    Text(caption)
                        .font(typography.subheadline)
                        .foregroundStyle(resolver.color(colors.textSecondary))
                }
            }
            Spacer()
            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(typography.body.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(resolver.color(colors.primary))
            }
        }
    }
}
