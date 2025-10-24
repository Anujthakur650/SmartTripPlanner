import CoreLocation
import StoreKit
import SwiftUI
import UIKit
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject var container: DependencyContainer
    @EnvironmentObject var appEnvironment: AppEnvironment
    @EnvironmentObject var privacySettings: PrivacySettingsService
    @EnvironmentObject var emailService: EmailService
    @EnvironmentObject var accountService: AccountService
    @Environment(\.openURL) private var openURL
    @Environment(\.requestReview) private var requestReview
    
    @State private var showDeletionConfirmation = false
    @State private var activeAlert: ActiveAlert?
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var locationStatus: CLAuthorizationStatus = .notDetermined
    @State private var isSigningIn = false
    
    var body: some View {
        NavigationStack {
            Form {
                accountSection
                privacySection
                syncSection
                legalSection
                dataSection
                supportSection
                aboutSection
            }
            .navigationTitle(L10n.Settings.title)
            .confirmationDialog(
                L10n.Settings.Data.confirmationTitle,
                isPresented: $showDeletionConfirmation,
                titleVisibility: .visible
            ) {
                Button(L10n.Settings.Data.confirmationAction, role: .destructive) {
                    Task {
                        await deleteAccountData()
                    }
                }
                Button(L10n.Settings.Data.confirmationCancel, role: .cancel) {}
            } message: {
                Text(L10n.Settings.Data.confirmationMessage)
            }
            .alert(item: $activeAlert) { alert in
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text(alert.dismissTitle)) {
                        if alert.shouldResetDeletionState {
                            accountService.resetDeletionState()
                        }
                    }
                )
            }
            .task {
                await refreshNotificationAuthorizationStatus()
                refreshLocationAuthorizationStatus()
            }
            .onReceive(accountService.$deletionState) { state in
                handleDeletion(state)
            }
        }
    }
    
    @ViewBuilder
    private var accountSection: some View {
        Section(L10n.Settings.accountSection) {
            if emailService.isSignedIn, let email = emailService.userEmail {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.Settings.Account.signedInAs)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text(email)
                        .font(.body)
                }
                Button(L10n.Settings.Account.signOut, role: .destructive) {
                    accountService.signOut()
                }
            } else {
                Text(L10n.Settings.Account.signInDescription)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button {
                    Task {
                        await signIn()
                    }
                } label: {
                    if isSigningIn {
                        HStack {
                            ProgressView()
                            Text(L10n.Settings.Account.signIn)
                        }
                    } else {
                        Text(L10n.Settings.Account.signIn)
                    }
                }
                .disabled(isSigningIn)
            }
            Button(L10n.Settings.Account.manageSubscriptions) {
                openSubscriptionManagement()
            }
        }
    }
    
    @ViewBuilder
    private var privacySection: some View {
        Section(L10n.Settings.privacySection) {
            Toggle(L10n.Settings.Privacy.analytics, isOn: $privacySettings.analyticsEnabled)
            Toggle(L10n.Settings.Privacy.personalization, isOn: $privacySettings.personalizationEnabled)
            Toggle(L10n.Settings.Privacy.diagnostics, isOn: $privacySettings.diagnosticsEnabled)
            Toggle(L10n.Settings.Privacy.notifications, isOn: $privacySettings.notificationsEnabled)
                .onChange(of: privacySettings.notificationsEnabled) { newValue in
                    guard newValue else { return }
                    requestNotificationAuthorization()
                }
            if notificationStatus == .denied {
                Button(L10n.Settings.Privacy.openSettings) {
                    openSystemSettings()
                }
                .font(.footnote)
                .foregroundColor(.accentColor)
                Text(L10n.Settings.Privacy.notificationsDenied)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Toggle(L10n.Settings.Privacy.location, isOn: $privacySettings.locationServicesEnabled)
                .onChange(of: privacySettings.locationServicesEnabled) { newValue in
                    if newValue {
                        requestLocationAuthorization()
                    }
                }
            if locationStatus == .denied || locationStatus == .restricted {
                Button(L10n.Settings.Privacy.openSettings) {
                    openSystemSettings()
                }
                .font(.footnote)
                .foregroundColor(.accentColor)
                Text(L10n.Settings.Privacy.locationDenied)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Toggle(L10n.Settings.Privacy.backgroundRefresh, isOn: $privacySettings.backgroundRefreshEnabled)
        } footer: {
            Text(L10n.Settings.Privacy.footer)
        }
    }
    
    @ViewBuilder
    private var syncSection: some View {
        Section(L10n.Settings.syncSection) {
            HStack {
                Text(L10n.Settings.Sync.icloudStatus)
                Spacer()
                if appEnvironment.isSyncing {
                    ProgressView()
                    Text(L10n.Settings.Sync.statusSyncing)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(L10n.Settings.Sync.statusHealthy)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            if let lastSync = container.syncService.lastSyncDate {
                Text(L10n.Settings.Sync.lastSynced(lastSync))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Button {
                Task {
                    await performManualSync()
                }
            } label: {
                Text(L10n.Settings.Sync.syncNow)
            }
            .disabled(appEnvironment.isSyncing)
        }
    }
    
    @ViewBuilder
    private var legalSection: some View {
        Section(L10n.Settings.legalSection) {
            if let privacyPolicyURL = URL(string: "https://example.com/privacy") {
                Link(L10n.Settings.Legal.privacyPolicy, destination: privacyPolicyURL)
            }
            if let termsURL = URL(string: "https://example.com/terms") {
                Link(L10n.Settings.Legal.termsOfService, destination: termsURL)
            }
            if let dataSafetyURL = URL(string: "https://example.com/privacy/data-safety") {
                Link(L10n.Settings.Legal.dataSafety, destination: dataSafetyURL)
            }
        }
    }
    
    @ViewBuilder
    private var dataSection: some View {
        Section(L10n.Settings.dataSection) {
            Button(L10n.Settings.Data.delete, role: .destructive) {
                showDeletionConfirmation = true
            }
            .disabled(accountService.deletionState == .deleting)
            if accountService.deletionState == .deleting {
                HStack(spacing: 12) {
                    ProgressView()
                    Text(L10n.Settings.Data.deletionInProgress)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            if let lastDeletion = accountService.lastDeletionDate {
                Text(L10n.Settings.lastDeletion(date: lastDeletion))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Button(L10n.Settings.Data.openSettings) {
                openSystemSettings()
            }
        }
    }
    
    @ViewBuilder
    private var supportSection: some View {
        Section(L10n.Settings.supportSection) {
            Button(L10n.Settings.Support.rateApp) {
                requestReview()
            }
            Button(L10n.Settings.Support.contactSupport) {
                contactSupport()
            }
            Button(L10n.Settings.Support.diagnostics) {
                sendDiagnosticsSnapshot()
            }
        }
    }
    
    @ViewBuilder
    private var aboutSection: some View {
        Section(L10n.Settings.aboutSection) {
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
            let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
            HStack {
                Text(L10n.Settings.About.versionLabel)
                Spacer()
                Text(L10n.Settings.versionLabel(version: version, build: build))
                    .foregroundStyle(.secondary)
            }
            if let websiteURL = URL(string: "https://smarttripplanner.app") {
                Link(L10n.Settings.About.website, destination: websiteURL)
            }
        }
    }
    
    private func signIn() async {
        guard !isSigningIn else { return }
        isSigningIn = true
        do {
            try await emailService.signIn()
        } catch {
            activeAlert = .signInError(error.localizedDescription)
        }
        isSigningIn = false
    }
    
    private func openSubscriptionManagement() {
        guard let url = URL(string: "https://apps.apple.com/account/subscriptions") else { return }
        openURL(url)
    }
    
    private func requestNotificationAuthorization() {
        Task {
            let center = UNUserNotificationCenter.current()
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                let settings = await center.notificationSettings()
                await MainActor.run {
                    notificationStatus = settings.authorizationStatus
                    privacySettings.notificationsEnabled = granted
                }
            } catch {
                await MainActor.run {
                    notificationStatus = .denied
                    privacySettings.notificationsEnabled = false
                }
            }
        }
    }
    
    private func refreshNotificationAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        await MainActor.run {
            notificationStatus = settings.authorizationStatus
            if settings.authorizationStatus == .denied {
                privacySettings.notificationsEnabled = false
            }
        }
    }
    
    private func refreshLocationAuthorizationStatus() {
        let manager = CLLocationManager()
        locationStatus = manager.authorizationStatus
        if locationStatus == .denied || locationStatus == .restricted {
            privacySettings.locationServicesEnabled = false
        }
    }
    
    private func requestLocationAuthorization() {
        container.mapsService.requestLocationPermission()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            refreshLocationAuthorizationStatus()
        }
    }
    
    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
    
    private func handleDeletion(_ state: AccountService.DeletionState) {
        switch state {
        case let .success(date):
            activeAlert = .deletionSuccess(date)
        case let .failure(message):
            activeAlert = .deletionFailure(message)
        default:
            break
        }
    }
    
    private func deleteAccountData() async {
        await accountService.deleteAccount()
    }
    
    private func performManualSync() async {
        guard !appEnvironment.isSyncing else { return }
        appEnvironment.isSyncing = true
        do {
            try await container.syncService.syncAllData()
        } catch {
            activeAlert = .syncFailure(error.localizedDescription)
        }
        appEnvironment.isSyncing = false
    }
    
    private func contactSupport() {
        guard let url = URL(string: "mailto:support@smarttripplanner.app") else { return }
        openURL(url)
    }
    
    private func sendDiagnosticsSnapshot() {
        if privacySettings.diagnosticsEnabled {
            container.analyticsService.logDiagnostics(event: "diagnostics_manual_snapshot", metadata: [
                "notifications": privacySettings.notificationsEnabled ? "enabled" : "disabled",
                "location": privacySettings.locationServicesEnabled ? "enabled" : "disabled"
            ])
            activeAlert = .diagnosticsShared
        } else {
            activeAlert = .diagnosticsDisabled
        }
    }
}

private enum ActiveAlert: Identifiable {
    case signInError(String)
    case deletionSuccess(Date)
    case deletionFailure(String)
    case syncFailure(String)
    case diagnosticsDisabled
    case diagnosticsShared
    
    var id: String {
        switch self {
        case let .signInError(message):
            return "signInError-\(message)"
        case let .deletionSuccess(date):
            return "deletionSuccess-\(date.timeIntervalSince1970)"
        case let .deletionFailure(message):
            return "deletionFailure-\(message)"
        case let .syncFailure(message):
            return "syncFailure-\(message)"
        case .diagnosticsDisabled:
            return "diagnosticsDisabled"
        case .diagnosticsShared:
            return "diagnosticsShared"
        }
    }
    
    var title: LocalizedStringKey {
        switch self {
        case .signInError:
            return L10n.Settings.Alert.signInErrorTitle
        case .deletionSuccess:
            return L10n.Settings.Alert.deletionSuccessTitle
        case .deletionFailure:
            return L10n.Settings.Alert.deletionFailureTitle
        case .syncFailure:
            return L10n.Settings.Alert.syncFailureTitle
        case .diagnosticsDisabled:
            return L10n.Settings.Alert.diagnosticsDisabledTitle
        case .diagnosticsShared:
            return L10n.Settings.Alert.diagnosticsSharedTitle
        }
    }
    
    var message: String {
        switch self {
        case let .signInError(message):
            return message
        case let .deletionSuccess(date):
            return L10n.Settings.deletionSuccess(date: date)
        case let .deletionFailure(message):
            return message.isEmpty ? NSLocalizedString("settings.data.error", comment: "Generic data deletion error") : message
        case let .syncFailure(message):
            return message.isEmpty ? L10n.Settings.Alert.syncFailureMessage : message
        case .diagnosticsDisabled:
            return L10n.Settings.Alert.diagnosticsDisabledMessage
        case .diagnosticsShared:
            return L10n.Settings.Alert.diagnosticsSharedMessage
        }
    }
    
    var dismissTitle: LocalizedStringKey {
        L10n.Settings.Alert.dismiss
    }
    
    var shouldResetDeletionState: Bool {
        switch self {
        case .deletionSuccess, .deletionFailure:
            return true
        default:
            return false
        }
    }
}
