import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var container: DependencyContainer
    @EnvironmentObject var appEnvironment: AppEnvironment
    @State private var notificationsEnabled = true
    @State private var locationEnabled = true
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Preferences") {
                    Toggle("Enable Notifications", isOn: $notificationsEnabled)
                    Toggle("Location Services", isOn: $locationEnabled)
                }
                
                Section("Sync") {
                    HStack {
                        Text("iCloud Sync")
                        Spacer()
                        switch container.syncService.syncStatus {
                        case .idle:
                            Image(systemName: "icloud")
                                .foregroundColor(.blue)
                        case .syncing:
                            ProgressView()
                        case .success:
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        case .failed:
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                        }
                    }
                    
                    if let lastSyncDate = container.syncService.lastSyncDate {
                        Text("Last synced \(lastSyncDate.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if case .failed(let error) = container.syncService.syncStatus {
                        Text(error.localizedDescription)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    
                    Button(action: {
                        Task {
                            await performSync()
                        }
                    }) {
                        Text("Sync Now")
                    }
                    .disabled(appEnvironment.isSyncing)
                }
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    Link("Privacy Policy", destination: URL(string: "https://example.com/privacy")!)
                    Link("Terms of Service", destination: URL(string: "https://example.com/terms")!)
                }
                
                Section {
                    Button("Sign Out", role: .destructive) {
                        signOut()
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
    
    private func performSync() async {
        do {
            try await container.syncService.syncAllData()
        } catch {
            appEnvironment.isSyncing = false
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
