import Foundation
import GoogleSignIn
import UIKit

@MainActor
final class EmailService: ObservableObject {
    enum EmailServiceError: LocalizedError, Identifiable {
        case notSignedIn
        case missingAccessToken
        case apiFailure(String)
        
        var id: String { localizedDescription }
        
        var errorDescription: String? {
            switch self {
            case .notSignedIn:
                return "You must be signed in to Gmail to fetch reservations."
            case .missingAccessToken:
                return "We couldn't access your Gmail account credentials."
            case let .apiFailure(message):
                return message
            }
        }
        
        var recoverySuggestion: String? {
            switch self {
            case .notSignedIn:
                return "Sign in with Google to continue."
            case .missingAccessToken:
                return "Try signing out and back in to refresh your session."
            case .apiFailure:
                return "Please try again in a few moments."
            }
        }
    }
    
    @Published private(set) var isSignedIn: Bool = false
    @Published private(set) var userEmail: String?
    @Published private(set) var lastSyncedAt: Date?
    
    private let gmailClient: GmailClient
    private var userContext: GoogleUserContext?
    
    init(gmailClient: GmailClient = GmailAPIClient(), userContext: GoogleUserContext? = nil) {
        self.gmailClient = gmailClient
        self.userContext = userContext
        if let userContext {
            self.isSignedIn = true
            self.userEmail = userContext.email
        }
    }
    
    func signIn() async throws {
        guard let windowScene = await UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = await windowScene.windows.first?.rootViewController else {
            throw EmailServiceError.apiFailure("Unable to find a window to present the sign-in flow.")
        }
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
        let context = GIDUserContext(user: result.user)
        userContext = context
        userEmail = context.email
        isSignedIn = true
    }
    
    func restorePreviousSignIn() {
        if let user = GIDSignIn.sharedInstance.currentUser {
            let context = GIDUserContext(user: user)
            userContext = context
            userEmail = context.email
            isSignedIn = true
        }
    }
    
    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        userContext = nil
        isSignedIn = false
        userEmail = nil
        lastSyncedAt = nil
    }
    
    func fetchEmails(maxResults: Int = 25) async throws -> [EmailMessage] {
        guard let userContext, isSignedIn else {
            throw EmailServiceError.notSignedIn
        }
        try await userContext.refreshTokensIfNeeded()
        guard let token = userContext.accessToken else {
            throw EmailServiceError.missingAccessToken
        }
        do {
            let gmailMessages = try await gmailClient.fetchMessages(accessToken: token, maxResults: maxResults)
            let reservations = gmailMessages.map { message in
                EmailMessage(
                    id: message.id,
                    subject: message.subject,
                    from: message.from,
                    date: message.date,
                    snippet: message.snippet,
                    body: message.body,
                    reservation: ReservationParser.parse(message: message)
                )
            }
            lastSyncedAt = Date()
            return reservations.sorted { $0.date > $1.date }
        } catch let error as GmailAPIClient.APIError {
            throw EmailServiceError.apiFailure(error.localizedDescription)
        } catch {
            throw EmailServiceError.apiFailure(error.localizedDescription)
        }
    }
}

struct EmailMessage: Identifiable, Equatable {
    struct Reservation: Identifiable, Equatable {
        let id = UUID()
        let provider: String
        let confirmationCode: String?
        let travelDate: Date?
        let location: String?
        let metadata: [String: String]
    }
    
    let id: String
    let subject: String
    let from: String
    let date: Date
    let snippet: String
    let body: String
    let reservation: Reservation?
}

protocol GoogleUserContext {
    var email: String? { get }
    func refreshTokensIfNeeded() async throws
    var accessToken: String? { get }
}

struct GIDUserContext: GoogleUserContext {
    private let user: GIDGoogleUser
    
    init(user: GIDGoogleUser) {
        self.user = user
    }
    
    var email: String? {
        user.profile?.email
    }
    
    func refreshTokensIfNeeded() async throws {
        _ = try await user.refreshTokensIfNeeded()
    }
    
    var accessToken: String? {
        user.accessToken?.tokenString
    }
}

// MARK: - Gmail API Client

protocol GmailClient {
    func fetchMessages(accessToken: String, maxResults: Int) async throws -> [GmailMessage]
}

struct GmailMessage: Equatable {
    let id: String
    let subject: String
    let from: String
    let date: Date
    let snippet: String
    let body: String
}

struct GmailAPIClient: GmailClient {
    enum APIError: LocalizedError {
        case unauthorized
        case server(String)
        case decoding(Error)
        case invalidResponse
        
        var errorDescription: String? {
            switch self {
            case .unauthorized:
                return "Gmail authorization failed."
            case let .server(message):
                return message
            case let .decoding(error):
                return "Failed to decode Gmail response: \(error.localizedDescription)"
            case .invalidResponse:
                return "Unexpected response from Gmail."
            }
        }
    }
    
    private struct MessageListResponse: Decodable {
        struct MessageIdentifier: Decodable { let id: String }
        let messages: [MessageIdentifier]?
    }
    
    private struct MessageResponse: Decodable {
        struct Payload: Decodable {
            struct Body: Decodable {
                let size: Int
                let data: String?
            }
            let mimeType: String
            let filename: String?
            let headers: [Header]
            let body: Body
            let parts: [Payload]?
        }
        struct Header: Decodable {
            let name: String
            let value: String
        }
        let id: String
        let snippet: String
        let internalDate: String?
        let payload: Payload
    }
    
    static let defaultQuery = "category:travel OR subject:itinerary OR subject:reservation OR subject:booking"
    private let session: URLSession
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    func fetchMessages(accessToken: String, maxResults: Int) async throws -> [GmailMessage] {
        guard let listURL = URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages?maxResults=\(maxResults)&q=\(Self.defaultQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") else {
            throw APIError.invalidResponse
        }
        let listData = try await request(url: listURL, accessToken: accessToken)
        let list = try decode(MessageListResponse.self, from: listData)
        let identifiers = list.messages ?? []
        var messages: [GmailMessage] = []
        for identifier in identifiers {
            if let message = try await fetchMessage(id: identifier.id, accessToken: accessToken) {
                messages.append(message)
            }
        }
        return messages
    }
    
    private func fetchMessage(id: String, accessToken: String) async throws -> GmailMessage? {
        guard let detailURL = URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages/\(id)?format=full") else {
            throw APIError.invalidResponse
        }
        let data = try await request(url: detailURL, accessToken: accessToken)
        let response = try decode(MessageResponse.self, from: data)
        guard let fromHeader = response.payload.headers.first(where: { $0.name.caseInsensitiveCompare("From") == .orderedSame })?.value,
              let subjectHeader = response.payload.headers.first(where: { $0.name.caseInsensitiveCompare("Subject") == .orderedSame })?.value else {
            return nil
        }
        let date = parseDate(from: response) ?? Date()
        let body = extractBody(from: response.payload)
        return GmailMessage(
            id: response.id,
            subject: subjectHeader,
            from: fromHeader,
            date: date,
            snippet: response.snippet,
            body: body
        )
    }
    
    private func request(url: URL, accessToken: String) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        switch http.statusCode {
        case 200:
            return data
        case 401:
            throw APIError.unauthorized
        default:
            let message = String(data: data, encoding: .utf8) ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            throw APIError.server(message)
        }
    }
    
    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }
    
    private func extractBody(from payload: MessageResponse.Payload) -> String {
        if let data = payload.body.data, let decoded = decodeBase64URLSafe(data) {
            return decoded
        }
        if let parts = payload.parts {
            for part in parts {
                let body = extractBody(from: part)
                if !body.isEmpty {
                    return body
                }
            }
        }
        return ""
    }
    
    private func decodeBase64URLSafe(_ string: String) -> String? {
        var base64 = string.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        let padding = base64.count % 4
        if padding > 0 {
            base64.append(String(repeating: "=", count: 4 - padding))
        }
        guard let data = Data(base64Encoded: base64) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    private func parseDate(from response: MessageResponse) -> Date? {
        if let dateHeader = response.payload.headers.first(where: { $0.name.caseInsensitiveCompare("Date") == .orderedSame })?.value {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
            if let date = formatter.date(from: dateHeader) {
                return date
            }
            formatter.dateFormat = "dd MMM yyyy HH:mm:ss Z"
            if let date = formatter.date(from: dateHeader) {
                return date
            }
        }
        if let internalDate = response.internalDate, let milliseconds = Double(internalDate) {
            return Date(timeIntervalSince1970: milliseconds / 1000)
        }
        return nil
    }
}

// MARK: - Reservation Parsing

struct ReservationParser {
    static func parse(message: GmailMessage) -> EmailMessage.Reservation? {
        let normalizedBody = message.body.lowercased()
        let normalizedSubject = message.subject.lowercased()
        let provider = extractProvider(from: message.from, subject: message.subject)
        let confirmation = extractConfirmationCode(from: normalizedBody) ?? extractConfirmationCode(from: normalizedSubject)
        let travelDate = extractDate(from: message.body) ?? extractDate(from: message.subject)
        let location = extractLocation(from: message.body)
        let metadata = makeMetadata(provider: provider, confirmation: confirmation, travelDate: travelDate, location: location)
        if provider.isEmpty && confirmation == nil && travelDate == nil { return nil }
        return EmailMessage.Reservation(
            provider: provider.isEmpty ? "Reservation" : provider,
            confirmationCode: confirmation,
            travelDate: travelDate,
            location: location,
            metadata: metadata
        )
    }
    
    private static func extractProvider(from fromHeader: String, subject: String) -> String {
        if let match = fromHeader.split(separator: "<").first {
            let provider = match.trimmingCharacters(in: .whitespacesAndNewlines)
            if !provider.isEmpty { return provider }
        }
        let keywords = ["airbnb", "delta", "united", "american", "booking", "expedia", "marriott", "hilton", "trainline", "amtrak"]
        for keyword in keywords {
            if subject.lowercased().contains(keyword) {
                return keyword.capitalized
            }
        }
        return subject.split(separator: "-").first.map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) } ?? ""
    }
    
    private static func extractConfirmationCode(from text: String) -> String? {
        let patterns = [
            "confirmation\\s*(code|number|#|id)\\s*[:\\-]?\\s*([A-Z0-9]{5,8})",
            "booking\\s*(code|reference)\\s*[:\\-]?\\s*([A-Z0-9]{5,8})",
            "record\\s*locator\\s*[:\\-]?\\s*([A-Z0-9]{5,8})"
        ]
        for pattern in patterns {
            if let match = text.matching(pattern, options: .caseInsensitive), match.count > 2 {
                return String(match[2]).uppercased()
            }
        }
        return nil
    }
    
    private static func extractDate(from text: String) -> Date? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        return detector.matches(in: text, options: [], range: range).first?.date
    }
    
    private static func extractLocation(from text: String) -> String? {
        let pattern = "to\\s+([A-Za-z\\s',-]{3,50})"
        if let match = text.matching(pattern, options: .caseInsensitive), match.count > 1 {
            return String(match[1]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }
    
    private static func makeMetadata(provider: String, confirmation: String?, travelDate: Date?, location: String?) -> [String: String] {
        var metadata: [String: String] = [:]
        if !provider.isEmpty {
            metadata["provider"] = provider
        }
        if let confirmation {
            metadata["confirmation"] = confirmation
        }
        if let travelDate {
            metadata["travelDate"] = ISO8601DateFormatter().string(from: travelDate)
        }
        if let location {
            metadata["location"] = location
        }
        return metadata
    }
}

private extension String {
    func matching(_ pattern: String, options: NSRegularExpression.Options = []) -> [Substring]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return nil }
        let range = NSRange(startIndex..., in: self)
        guard let match = regex.firstMatch(in: self, options: [], range: range) else { return nil }
        return (0..<match.numberOfRanges).compactMap { index in
            guard let range = Range(match.range(at: index), in: self) else { return nil }
            return self[range]
        }
    }
}
