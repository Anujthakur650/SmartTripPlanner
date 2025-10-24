import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @Environment(\.colorScheme) private var colorScheme
    @State private var notificationsEnabled = true
    @State private var locationEnabled = true
    
    private var theme: Theme { appEnvironment.theme }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing.l) {
                    SectionHeader(
                        title: "Preferences",
                        caption: "Tailor SmartTrip Planner to your workflow"
                    )
                    Card(style: .standard) {
                        VStack(spacing: theme.spacing.m) {
                            FormToggleRow(
                                title: "Enable notifications",
                                isOn: $notificationsEnabled,
                                helper: "Receive gentle nudges for itinerary tasks"
                            )
                            FormToggleRow(
                                title: "Share location",
                                isOn: $locationEnabled,
                                helper: "Used to surface relevant places and weather"
                            )
                        }
                    }
                    SectionHeader(
                        title: "Sync & account",
                        caption: "Keep everything backed up and current"
                    )
                    Card(style: .standard) {
                        VStack(alignment: .leading, spacing: theme.spacing.m) {
                            if appEnvironment.isSyncing {
                                LoadingStateView(message: "Syncing your data…")
                            } else {
                                ListRow(
                                    icon: "icloud",
                                    title: "iCloud sync",
                                    subtitle: "Last synced moments ago",
                                    tagText: "Active",
                                    tagStyle: .success
                                ) {
                                    Image(systemName: "checkmark")
                                }
                            }
                            AppButton(
                                title: appEnvironment.isSyncing ? "Syncing" : "Sync now",
                                style: .tinted,
                                isLoading: appEnvironment.isSyncing,
                                action: triggerSync
                            )
                        }
                    }
                    SectionHeader(
                        title: "About",
                        caption: "Transparency builds trust"
                    )
                    Card(style: .standard) {
                        VStack(spacing: theme.spacing.m) {
                            ListRow(
                                icon: "number",
                                title: "Version",
                                subtitle: "1.0.0"
                            )
                            ListRow(
                                icon: "lock.doc",
                                title: "Privacy policy",
                                subtitle: "Understand how we protect your data"
                            ) {
                                Image(systemName: "arrow.up.right.square")
                            }
                            ListRow(
                                icon: "doc.text",
                                title: "Terms of service",
                                subtitle: "Review the agreement"
                            ) {
                                Image(systemName: "arrow.up.right.square")
                            }
                        }
                    }
                    AppButton(title: "Sign out", style: .destructive, action: signOut)
                }
                .padding(.horizontal, theme.spacing.l)
                .padding(.vertical, theme.spacing.l)
            }
            .background(theme.colors.background.resolved(for: colorScheme))
            .navigationTitle("Settings")
        }
    }
    
    private func triggerSync() {
        guard !appEnvironment.isSyncing else { return }
        appEnvironment.isSyncing = true
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                appEnvironment.isSyncing = false
            }
        }
    }
    
    private func signOut() {
    }
}

#Preview {
    SettingsView()
        .environmentObject(DependencyContainer())
        .environmentObject(AppEnvironment())
}
