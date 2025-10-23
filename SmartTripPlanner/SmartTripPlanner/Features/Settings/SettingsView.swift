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
                        if appEnvironment.isSyncing {
                            ProgressView()
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                    
                    Button("Sync Now") {
                        Task {
                            await performSync()
                        }
                    }
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
        appEnvironment.isSyncing = true
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        appEnvironment.isSyncing = false
    }
    
    private func signOut() {
    }
}

#Preview {
    SettingsView()
        .environmentObject(DependencyContainer())
        .environmentObject(AppEnvironment())
}
