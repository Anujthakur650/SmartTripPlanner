import Foundation
import GoogleSignIn

@MainActor
class EmailService: ObservableObject {
    @Published var isSignedIn = false
    @Published var userEmail: String?
    
    func signIn() async throws {
        guard let windowScene = await UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = await windowScene.windows.first?.rootViewController else {
            throw NSError(domain: "EmailService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No root view controller"])
        }
        
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
        isSignedIn = true
        userEmail = result.user.profile?.email
    }
    
    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        isSignedIn = false
        userEmail = nil
    }
    
    func fetchEmails() async throws -> [EmailMessage] {
        guard isSignedIn else {
            throw NSError(domain: "EmailService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not signed in"])
        }
        return []
    }
}

struct EmailMessage: Identifiable {
    let id: String
    let subject: String
    let from: String
    let date: Date
    let body: String
}
