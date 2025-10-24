import SwiftUI
import MapKit

struct DesignSystemCatalog: View {
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @Environment(\.colorScheme) private var colorScheme
    @State private var sampleDestination: String = "Lisbon"
    @State private var sampleToggle: Bool = true
    
    private var theme: Theme {
        appEnvironment.theme
    }
    
    var body: some View {
        let spacing = theme.spacing
        ScrollView {
            VStack(alignment: .leading, spacing: spacing.xl) {
                paletteSection
                typographySection
                spacingSection
                componentsSection
            }
            .padding(.horizontal, spacing.l)
            .padding(.vertical, spacing.xl)
        }
        .background(theme.colors.background.resolved(for: colorScheme))
    }
    
    private var paletteSection: some View {
        let spacing = theme.spacing
        let columns = [GridItem(.flexible(), spacing: spacing.m), GridItem(.flexible(), spacing: spacing.m)]
        return VStack(alignment: .leading, spacing: spacing.m) {
            SectionHeader(
                title: "Color Palette",
                caption: "Dynamic tokens for light and dark modes"
            )
            LazyVGrid(columns: columns, spacing: spacing.m) {
                paletteItem("Primary", swatch: theme.colors.primary, foreground: theme.colors.onPrimary)
                paletteItem("Accent", swatch: theme.colors.accent, foreground: theme.colors.onAccent)
                paletteItem("Background", swatch: theme.colors.background)
                paletteItem("Surface", swatch: theme.colors.surface)
                paletteItem("Success", swatch: theme.colors.success, foreground: theme.colors.onSuccess)
                paletteItem("Warning", swatch: theme.colors.warning, foreground: theme.colors.onWarning)
                paletteItem("Error", swatch: theme.colors.error, foreground: theme.colors.onError)
                paletteItem("Info", swatch: theme.colors.info, foreground: theme.colors.onInfo)
            }
        }
    }
    
    private var typographySection: some View {
        let spacing = theme.spacing
        return VStack(alignment: .leading, spacing: spacing.m) {
            SectionHeader(
                title: "Typography",
                caption: "Rounded SF Pro styles"
            )
            VStack(alignment: .leading, spacing: spacing.s) {
                typographyRow(label: "Large Title", sample: "Plan with confidence", font: theme.typography.largeTitle)
                typographyRow(label: "Title", sample: "Upcoming adventures", font: theme.typography.title)
                typographyRow(label: "Headline", sample: "Essential travel steps", font: theme.typography.headline)
                typographyRow(label: "Body", sample: "Organize all of your journeys in one calm workspace.", font: theme.typography.body)
                typographyRow(label: "Caption", sample: "Secondary context and helper text", font: theme.typography.caption)
            }
        }
    }
    
    private var spacingSection: some View {
        let spacing = theme.spacing
        return VStack(alignment: .leading, spacing: spacing.m) {
            SectionHeader(
                title: "Spacing & Radius",
                caption: "Consistent rhythm and softness"
            )
            HStack(alignment: .bottom, spacing: spacing.s) {
                spacingBar(label: "XXS", value: theme.spacing.xxs)
                spacingBar(label: "XS", value: theme.spacing.xs)
                spacingBar(label: "S", value: theme.spacing.s)
                spacingBar(label: "M", value: theme.spacing.m)
                spacingBar(label: "L", value: theme.spacing.l)
                spacingBar(label: "XL", value: theme.spacing.xl)
            }
            HStack(spacing: spacing.s) {
                radiusChip(label: "S", value: theme.radii.s)
                radiusChip(label: "M", value: theme.radii.m)
                radiusChip(label: "L", value: theme.radii.l)
                radiusChip(label: "XL", value: theme.radii.xl)
                radiusChip(label: "Pill", value: theme.radii.pill)
            }
        }
    }
    
    private var componentsSection: some View {
        let spacing = theme.spacing
        return VStack(alignment: .leading, spacing: spacing.l) {
            SectionHeader(
                title: "Components",
                caption: "Composable building blocks"
            )
            buttonsShowcase
            cardShowcase
            listRowShowcase
            mapShowcase
            timelineShowcase
            statesShowcase
            formShowcase
        }
    }
    
    private var buttonsShowcase: some View {
        let spacing = theme.spacing
        return VStack(alignment: .leading, spacing: spacing.s) {
            Text("Buttons")
                .font(theme.typography.subheadline)
                .foregroundStyle(resolved(theme.colors.textSecondary))
            HStack(spacing: spacing.s) {
                AppButton(title: "Primary", style: .primary, fillWidth: false, action: {})
                AppButton(title: "Secondary", style: .secondary, fillWidth: false, action: {})
            }
            HStack(spacing: spacing.s) {
                AppButton(title: "Tinted", style: .tinted, fillWidth: false, action: {})
                AppButton(title: "Ghost", style: .ghost, fillWidth: false, action: {})
                AppButton(title: "Danger", style: .destructive, fillWidth: false, action: {})
            }
        }
    }
    
    private var cardShowcase: some View {
        Card(title: "Amalfi Escape", subtitle: "2 – 9 June • 2 travelers") {
            let spacing = theme.spacing
            TagLabel(text: "Confirmed", style: .success)
            Rectangle()
                .fill(resolved(theme.colors.border))
                .frame(height: 1)
            HStack(spacing: spacing.m) {
                Image(systemName: "airplane.departs")
                    .foregroundStyle(resolved(theme.colors.info))
                VStack(alignment: .leading, spacing: spacing.xs) {
                    Text("Flight AZ 611")
                        .font(theme.typography.body)
                        .foregroundStyle(resolved(theme.colors.textPrimary))
                    Text("Departure 09:05 — JFK")
                        .font(theme.typography.caption)
                        .foregroundStyle(resolved(theme.colors.textSecondary))
                }
                Spacer()
            }
        }
    }
    
    private var listRowShowcase: some View {
        let spacing = theme.spacing
        return VStack(alignment: .leading, spacing: spacing.s) {
            Text("List Row")
                .font(theme.typography.subheadline)
                .foregroundStyle(resolved(theme.colors.textSecondary))
            ListRow(
                icon: "doc.text.fill",
                title: "Passport",
                subtitle: "Renewed May 2024",
                tagText: "Verified",
                tagStyle: .primary
            ) {
                Image(systemName: "chevron.right")
            }
        }
    }
    
    private var mapShowcase: some View {
        let tags = [
            MapCard.TagInfo(text: "Food", style: .info),
            MapCard.TagInfo(text: "Saved", style: .primary)
        ]
        return VStack(alignment: .leading, spacing: theme.spacing.s) {
            Text("Map Card")
                .font(theme.typography.subheadline)
                .foregroundStyle(resolved(theme.colors.textSecondary))
            MapCard(
                title: "Blue Bottle Coffee",
                subtitle: "66 Mint St, San Francisco",
                coordinate: CLLocationCoordinate2D(latitude: 37.786, longitude: -122.399),
                footnote: "8 min walk • Open until 6 pm",
                tags: tags,
                actionTitle: "Open",
                action: {}
            )
        }
    }
    
    private var timelineShowcase: some View {
        let spacing = theme.spacing
        return VStack(alignment: .leading, spacing: spacing.s) {
            Text("Timeline")
                .font(theme.typography.subheadline)
                .foregroundStyle(resolved(theme.colors.textSecondary))
            VStack(alignment: .leading, spacing: spacing.m) {
                TimelineItem(
                    icon: "sunrise.fill",
                    time: "08:30",
                    title: "Breakfast at hotel",
                    subtitle: "Cafe Aurora",
                    detail: "Reservation for 2",
                    status: .completed
                )
                TimelineItem(
                    icon: "photo.on.rectangle",
                    time: "10:00",
                    title: "Coastal hike",
                    subtitle: "Path of the Gods",
                    detail: "Pack water and sunscreen",
                    status: .inProgress
                )
                TimelineItem(
                    icon: "tram.fill",
                    time: "16:45",
                    title: "Ferry to Positano",
                    subtitle: "Pier 2",
                    detail: "Tickets confirmed",
                    status: .planned
                )
            }
        }
    }
    
    private var statesShowcase: some View {
        let spacing = theme.spacing
        return VStack(alignment: .leading, spacing: spacing.m) {
            Text("States")
                .font(theme.typography.subheadline)
                .foregroundStyle(resolved(theme.colors.textSecondary))
            EmptyStateView(
                icon: "tray",
                title: "No saved items",
                message: "Bookmark spots you love to build your travel shortlist.",
                actionTitle: "Browse",
                action: {}
            )
            LoadingStateView(message: "Syncing itinerary with iCloud…")
            ErrorSurface(
                title: "Connection lost",
                message: "We're retrying in the background. Check your connection or try again.",
                actionTitle: "Retry",
                action: {}
            )
        }
    }
    
    private var formShowcase: some View {
        let spacing = theme.spacing
        return VStack(alignment: .leading, spacing: spacing.s) {
            Text("Form Elements")
                .font(theme.typography.subheadline)
                .foregroundStyle(resolved(theme.colors.textSecondary))
            FormTextField(
                title: "Destination",
                placeholder: "Where to?",
                text: $sampleDestination,
                helper: "Use a city or country",
                icon: "mappin.and.ellipse"
            )
            FormToggleRow(
                title: "Smart reminders",
                isOn: $sampleToggle,
                helper: "Get notified when travel steps are due"
            )
        }
    }
    
    private func typographyRow(label: String, sample: String, font: Font) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
            Text(label)
                .font(theme.typography.caption)
                .foregroundStyle(resolved(theme.colors.textSecondary))
            Text(sample)
                .font(font)
                .foregroundStyle(resolved(theme.colors.textPrimary))
        }
    }
    
    private func spacingBar(label: String, value: CGFloat) -> some View {
        VStack(spacing: theme.spacing.xs) {
            RoundedRectangle(cornerRadius: theme.radii.s, style: .continuous)
                .fill(resolved(theme.colors.surfaceMuted))
                .frame(width: 28, height: max(16, value * 2))
            Text(label)
                .font(theme.typography.caption)
                .foregroundStyle(resolved(theme.colors.textSecondary))
        }
    }
    
    private func radiusChip(label: String, value: CGFloat) -> some View {
        VStack(spacing: theme.spacing.xs) {
            RoundedRectangle(cornerRadius: min(value, 20), style: .continuous)
                .stroke(resolved(theme.colors.border), lineWidth: 1)
                .frame(width: 64, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: min(value, 20), style: .continuous)
                        .fill(resolved(theme.colors.surface))
                )
            Text(label)
                .font(theme.typography.caption)
                .foregroundStyle(resolved(theme.colors.textSecondary))
        }
    }
    
    private func paletteItem(_ title: String, swatch: DynamicColor, foreground: DynamicColor? = nil) -> some View {
        let background = swatch.resolved(for: colorScheme)
        let textColor = (foreground ?? theme.colors.textPrimary).resolved(for: colorScheme)
        return RoundedRectangle(cornerRadius: theme.radii.m, style: .continuous)
            .fill(background)
            .frame(height: 90)
            .overlay(alignment: .leading) {
                VStack(alignment: .leading, spacing: theme.spacing.xs) {
                    Text(title)
                        .font(theme.typography.subheadline.weight(.semibold))
                        .foregroundStyle(textColor)
                    Text("Adapts to system appearance")
                        .font(theme.typography.caption)
                        .foregroundStyle(textColor.opacity(0.85))
                }
                .padding(theme.spacing.m)
            }
    }
    
    private func resolved(_ color: DynamicColor) -> Color {
        color.resolved(for: colorScheme)
    }
}

#Preview("Catalog – Light") {
    DesignSystemCatalog()
        .environmentObject(AppEnvironment())
        .environmentObject(NavigationCoordinator())
}

#Preview("Catalog – Dark XXL") {
    DesignSystemCatalog()
        .environmentObject(AppEnvironment())
        .environmentObject(NavigationCoordinator())
        .environment(\.colorScheme, .dark)
        .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
}
