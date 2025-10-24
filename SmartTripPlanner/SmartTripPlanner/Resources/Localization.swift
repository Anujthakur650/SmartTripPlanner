import Foundation
import SwiftUI

enum L10n {
    enum Tab {
        static let trips = LocalizedStringKey("tab.trips")
        static let planner = LocalizedStringKey("tab.planner")
        static let map = LocalizedStringKey("tab.map")
        static let packing = LocalizedStringKey("tab.packing")
        static let docs = LocalizedStringKey("tab.docs")
        static let settings = LocalizedStringKey("tab.settings")
    }
    
    enum Settings {
        static let title = LocalizedStringKey("settings.title")
        static let accountSection = LocalizedStringKey("settings.section.account")
        static let privacySection = LocalizedStringKey("settings.section.privacy")
        static let syncSection = LocalizedStringKey("settings.section.sync")
        static let dataSection = LocalizedStringKey("settings.section.data")
        static let supportSection = LocalizedStringKey("settings.section.support")
        static let aboutSection = LocalizedStringKey("settings.section.about")
        static let legalSection = LocalizedStringKey("settings.section.legal")
        
        enum Account {
            static let signedInAs = LocalizedStringKey("settings.account.signedInAs")
            static let signIn = LocalizedStringKey("settings.account.signIn")
            static let signInDescription = LocalizedStringKey("settings.account.signInDescription")
            static let signOut = LocalizedStringKey("settings.account.signOut")
            static let manageSubscriptions = LocalizedStringKey("settings.account.manageSubscriptions")
        }
        
        enum Privacy {
            static let analytics = LocalizedStringKey("settings.privacy.analytics")
            static let personalization = LocalizedStringKey("settings.privacy.personalization")
            static let diagnostics = LocalizedStringKey("settings.privacy.diagnostics")
            static let notifications = LocalizedStringKey("settings.privacy.notifications")
            static let notificationsDenied = LocalizedStringKey("settings.privacy.notificationsDenied")
            static let location = LocalizedStringKey("settings.privacy.location")
            static let locationDenied = LocalizedStringKey("settings.privacy.locationDenied")
            static let backgroundRefresh = LocalizedStringKey("settings.privacy.backgroundRefresh")
            static let openSettings = LocalizedStringKey("settings.privacy.openSettings")
            static let footer = LocalizedStringKey("settings.privacy.footer")
        }
        
        enum Sync {
            static let icloudStatus = LocalizedStringKey("settings.sync.icloudStatus")
            static let syncNow = LocalizedStringKey("settings.sync.syncNow")
            static let statusHealthy = LocalizedStringKey("settings.sync.status.healthy")
            static let statusSyncing = LocalizedStringKey("settings.sync.status.syncing")
            static func lastSynced(_ date: Date) -> String {
                let formatted = date.formatted(date: .abbreviated, time: .shortened)
                return String(
                    format: NSLocalizedString("settings.sync.lastSynced_format", comment: "Last successful sync timestamp"),
                    formatted
                )
            }
        }
        
        enum Data {
            static let export = LocalizedStringKey("settings.data.export")
            static let delete = LocalizedStringKey("settings.data.delete")
            static let deletionInProgress = LocalizedStringKey("settings.data.deletionInProgress")
            static let confirmationTitle = LocalizedStringKey("settings.data.confirmation.title")
            static let confirmationMessage = LocalizedStringKey("settings.data.confirmation.message")
            static let confirmationAction = LocalizedStringKey("settings.data.confirmation.action")
            static let confirmationCancel = LocalizedStringKey("settings.data.confirmation.cancel")
            static let openSettings = LocalizedStringKey("settings.data.openSettings")
            static let error = LocalizedStringKey("settings.data.error")
        }
        
        enum Legal {
            static let privacyPolicy = LocalizedStringKey("settings.legal.privacyPolicy")
            static let termsOfService = LocalizedStringKey("settings.legal.termsOfService")
            static let dataSafety = LocalizedStringKey("settings.legal.dataSafety")
        }
        
        enum Support {
            static let rateApp = LocalizedStringKey("settings.support.rateApp")
            static let contactSupport = LocalizedStringKey("settings.support.contactSupport")
            static let diagnostics = LocalizedStringKey("settings.support.diagnostics")
        }
        
        enum About {
            static let website = LocalizedStringKey("settings.about.website")
            static let versionLabel = LocalizedStringKey("settings.about.version")
        }
        
        enum Alert {
            static let signInErrorTitle = LocalizedStringKey("settings.alert.signInError.title")
            static let deletionSuccessTitle = LocalizedStringKey("settings.alert.deletionSuccess.title")
            static let deletionFailureTitle = LocalizedStringKey("settings.alert.deletionFailure.title")
            static let syncFailureTitle = LocalizedStringKey("settings.alert.syncFailure.title")
            static let diagnosticsDisabledTitle = LocalizedStringKey("settings.alert.diagnosticsDisabled.title")
            static let diagnosticsSharedTitle = LocalizedStringKey("settings.alert.diagnosticsShared.title")
            static let dismiss = LocalizedStringKey("settings.alert.dismiss")
            static let diagnosticsDisabledMessage = NSLocalizedString("settings.alert.diagnosticsDisabled.message", comment: "Message displayed when diagnostics sharing is disabled")
            static let diagnosticsSharedMessage = NSLocalizedString("settings.alert.diagnosticsShared.message", comment: "Confirmation that diagnostics were shared")
            static let syncFailureMessage = NSLocalizedString("settings.alert.syncFailure.message", comment: "Generic sync failure message")
        }
        
        static func versionLabel(version: String, build: String) -> String {
            String(
                format: NSLocalizedString("settings.about.version_format", comment: "App version and build label"),
                version,
                build
            )
        }
        
        static func lastDeletion(date: Date) -> String {
            let formatted = date.formatted(date: .abbreviated, time: .shortened)
            return String(
                format: NSLocalizedString("settings.dataDeletion.lastDeletion_format", comment: "Last data deletion timestamp"),
                formatted
            )
        }
        
        static func deletionSuccess(date: Date) -> String {
            let formatted = date.formatted(date: .abbreviated, time: .shortened)
            return String(
                format: NSLocalizedString("settings.dataDeletion.success_format", comment: "Data deletion success message"),
                formatted
            )
        }
    }
    
    enum Trips {
        static let title = LocalizedStringKey("trips.title")
        static let emptyStateTitle = LocalizedStringKey("trips.empty.title")
        static let emptyStateDescription = LocalizedStringKey("trips.empty.description")
        static let addTripButton = LocalizedStringKey("trips.addTripButton")
        static let newTripName = NSLocalizedString("trips.newTrip.name", comment: "Default name for newly created trips")
        static let newTripDestination = NSLocalizedString("trips.newTrip.destination", comment: "Default destination placeholder for newly created trips")
    }
    
    enum Docs {
        static let title = LocalizedStringKey("docs.title")
        static let emptyTitle = LocalizedStringKey("docs.empty.title")
        static let emptyDescription = LocalizedStringKey("docs.empty.description")
        static let newDocumentName = NSLocalizedString("docs.newDocument.name", comment: "Default title for newly created documents")
    }
}
