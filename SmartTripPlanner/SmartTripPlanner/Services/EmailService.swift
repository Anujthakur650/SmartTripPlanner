import Foundation
import GoogleSignIn
import UIKit

@MainActor
class EmailService: ObservableObject {
    enum ServiceError: LocalizedError {
        case missingRootViewController
        case signInRequired
        case missingAccessToken
        case rateLimited(retryAfter: TimeInterval)
        case underlying(Error)
        
        var errorDescription: String? {
            switch self {
            case .missingRootViewController:
                return "Unable to locate the root view controller."
            case .signInRequired:
                return "Please sign in to your Google account."
            case .missingAccessToken:
                return "Unable to access Gmail tokens."
            case let .rateLimited(retryAfter):
                return "Gmail rate limit exceeded. Try again in \(Int(retryAfter)) seconds."
            case let .underlying(error):
                return error.localizedDescription
            }
        }
    }
    
    @Published var isSignedIn = false
    @Published var userEmail: String?
    @Published private(set) var messages: [EmailMessage] = []
    @Published private(set) var lastError: Error?
    
    private let gmailClient: GmailClient
    private let parser: TravelReservationParser
    private let messageQuery = "(flight OR itinerary OR reservation OR hotel OR car rental)"
    private let maxMessages = 25
    
    init(gmailClient: GmailClient = DefaultGmailClient(), parser: TravelReservationParser = TravelReservationParser()) {
        self.gmailClient = gmailClient
        self.parser = parser
        if let user = GIDSignIn.sharedInstance.currentUser {
            isSignedIn = true
            userEmail = user.profile?.email
        }
    }
    
    func signIn() async throws {
        guard let windowScene = await UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = await windowScene.windows.first?.rootViewController else {
            throw ServiceError.missingRootViewController
        }
        let additionalScopes = ["https://www.googleapis.com/auth/gmail.readonly"]
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController,
                                                               hint: nil,
                                                               additionalScopes: additionalScopes)
        isSignedIn = true
        userEmail = result.user.profile?.email
    }
    
    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        isSignedIn = false
        userEmail = nil
        messages = []
    }
    
    func fetchEmails() async throws -> [EmailMessage] {
        guard let user = GIDSignIn.sharedInstance.currentUser else {
            throw ServiceError.signInRequired
        }
        let refreshedUser = try await user.refreshTokensIfNeeded()
        guard let token = refreshedUser.accessToken?.tokenString else {
            throw ServiceError.missingAccessToken
        }
        do {
            let emails = try await performFetch(accessToken: token, userEmail: refreshedUser.profile?.email)
            return emails
        } catch {
            throw error
        }
    }
    
    @discardableResult
    func performFetch(accessToken token: String, userEmail: String?) async throws -> [EmailMessage] {
        do {
            let list = try await gmailClient.listMessageIdentifiers(accessToken: token,
                                                                    query: messageQuery,
                                                                    maxResults: maxMessages)
            let identifiers = list.messages ?? []
            let client = gmailClient
            let reservationParser = parser
            var fetchedMessages: [EmailMessage] = []
            fetchedMessages.reserveCapacity(identifiers.count)
            try await withThrowingTaskGroup(of: EmailMessage?.self) { group in
                for identifier in identifiers {
                    group.addTask {
                        let message = try await client.fetchMessage(accessToken: token, id: identifier.id)
                        return try EmailMessage(message: message, parser: reservationParser)
                    }
                }
                for try await message in group {
                    if let message {
                        fetchedMessages.append(message)
                    }
                }
            }
            let sorted = fetchedMessages.sorted { $0.date > $1.date }
            messages = sorted
            if let userEmail {
                self.userEmail = userEmail
            }
            lastError = nil
            return sorted
        } catch let error as GmailClientError {
            switch error {
            case let .rateLimited(retryAfter):
                lastError = ServiceError.rateLimited(retryAfter: retryAfter)
                throw ServiceError.rateLimited(retryAfter: retryAfter)
            default:
                lastError = error
                throw ServiceError.underlying(error)
            }
        } catch {
            lastError = error
            throw ServiceError.underlying(error)
        }
    }
}

struct EmailMessage: Identifiable {
    let id: String
    let subject: String
    let from: String
    let date: Date
    let body: String
    let reservations: [TravelReservation]
    
    init(id: String, subject: String, from: String, date: Date, body: String, reservations: [TravelReservation]) {
        self.id = id
        self.subject = subject
        self.from = from
        self.date = date
        self.body = body
        self.reservations = reservations
    }
    
    init(message: GmailMessage, parser: TravelReservationParser) throws {
        guard let payload = message.payload else {
            throw GmailClientError.invalidResponse
        }
        let subject = payload.header(named: "Subject") ?? "(No Subject)"
        let from = payload.header(named: "From") ?? "Unknown"
        let date: Date
        if let internalDate = message.internalDate, let milliseconds = Int64(internalDate) {
            date = Date(timeIntervalSince1970: TimeInterval(milliseconds) / 1000)
        } else {
            date = Date()
        }
        let bodyData = payload.bodyData() ?? Data()
        let body = String(data: bodyData, encoding: .utf8) ?? (message.snippet ?? "")
        let reservations = parser.parse(subject: subject,
                                        body: body,
                                        messageId: message.id,
                                        receivedDate: date)
        self.init(id: message.id,
                  subject: subject,
                  from: from,
                  date: date,
                  body: body,
                  reservations: reservations)
    }
}
