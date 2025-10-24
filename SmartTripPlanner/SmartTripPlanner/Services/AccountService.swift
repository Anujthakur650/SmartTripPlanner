import Foundation

@MainActor
final class AccountService: ObservableObject {
    enum DeletionState: Equatable {
        case idle
        case deleting
        case success(Date)
        case failure(String)
    }
    
    @Published private(set) var deletionState: DeletionState = .idle
    @Published private(set) var lastDeletionDate: Date?
    
    private let emailService: EmailService
    private let syncService: SyncService
    private let privacySettings: PrivacySettingsService
    private let mapsService: MapsService
    private let analyticsService: AnalyticsService
    
    init(
        emailService: EmailService,
        syncService: SyncService,
        privacySettings: PrivacySettingsService,
        mapsService: MapsService,
        analyticsService: AnalyticsService
    ) {
        self.emailService = emailService
        self.syncService = syncService
        self.privacySettings = privacySettings
        self.mapsService = mapsService
        self.analyticsService = analyticsService
    }
    
    func signOut() {
        emailService.signOut()
        analyticsService.log(event: "account_sign_out")
    }
    
    func deleteAccount() async {
        if case .deleting = deletionState {
            return
        }
        analyticsService.log(event: "account_deletion_requested")
        deletionState = .deleting
        do {
            try await syncService.deleteAllData()
            mapsService.purgeLocalData()
            clearUserDefaults()
            privacySettings.resetToDefaults()
            emailService.signOut()
            let completionDate = Date()
            lastDeletionDate = completionDate
            deletionState = .success(completionDate)
            analyticsService.log(event: "account_deletion_completed")
        } catch {
            let message = error.localizedDescription
            deletionState = .failure(message)
            analyticsService.log(event: "account_deletion_failed", metadata: ["reason": message])
        }
    }
    
    func resetDeletionState() {
        if case .success = deletionState {
            deletionState = .idle
        } else if case .failure = deletionState {
            deletionState = .idle
        }
    }
    
    private func clearUserDefaults() {
        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleIdentifier)
        }
        UserDefaults.standard.synchronize()
    }
}
