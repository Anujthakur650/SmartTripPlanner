import Foundation
import GoogleSignIn
import Security
import UIKit

@MainActor
final class EmailService: ObservableObject {
    enum ImportState: Equatable {
        case idle
        case loading
        case success
        case failed(String)
    }
    
    static let gmailScopes = [
        "https://www.googleapis.com/auth/gmail.readonly",
        "https://www.googleapis.com/auth/gmail.labels",
        "https://www.googleapis.com/auth/userinfo.email"
    ]
    
    static let defaultTravelQuery = "category:travel OR subject:(itinerary OR reservation OR booking)"
    
    @Published private(set) var isSignedIn = false
    @Published private(set) var userEmail: String?
    @Published private(set) var importState: ImportState = .idle
    @Published private(set) var latestCandidates: [TripImportCandidate] = []
    @Published private(set) var lastImportDate: Date?
    
    private let analyticsService: AnalyticsService
    private let authenticator: GmailAuthenticating
    private let tokenStore: GmailTokenStore
    private let apiClient: GmailAPIClientProtocol
    private let parser: EmailParsing
    private let deduplicator: EmailDeduplicating
    private let dateProvider: () -> Date
    
    private var credential: GmailCredential?
    private var cachedLabelIDs: [String: String] = [:]
    
    private let processedLabelName = "SmartTripPlanner/Imported"
    private let travelFilterLabelName = "CATEGORY_PERSONAL"
    private let tokenRefreshTolerance: TimeInterval = 120
    
    init(
        analyticsService: AnalyticsService,
        authenticator: GmailAuthenticating = GoogleSignInAuthenticator(scopes: EmailService.gmailScopes),
        tokenStore: GmailTokenStore = KeychainTokenStore(service: "com.smarttripplanner.gmail"),
        apiClient: GmailAPIClientProtocol = GmailAPIClient(),
        parser: EmailParsing = EmailParser(),
        deduplicator: EmailDeduplicating = EmailDeduplicator(),
        dateProvider: @escaping () -> Date = Date.init,
        shouldAttemptRestore: Bool = true
    ) {
        self.analyticsService = analyticsService
        self.authenticator = authenticator
        self.tokenStore = tokenStore
        self.apiClient = apiClient
        self.parser = parser
        self.deduplicator = deduplicator
        self.dateProvider = dateProvider
        
        if let storedCredential = try? tokenStore.loadCredential() {
            self.credential = storedCredential
            self.userEmail = storedCredential.email
            self.isSignedIn = storedCredential.token.isValid(at: dateProvider(), tolerance: tokenRefreshTolerance)
        }
        
        if shouldAttemptRestore {
            Task {
                await self.restorePreviousSignInIfPossible()
            }
        }
    }
    
    func ensureSignedIn(presenting viewController: UIViewController? = nil) async throws {
        if let credential, credential.token.isValid(at: dateProvider(), tolerance: tokenRefreshTolerance) {
            isSignedIn = true
            return
        }
        
        do {
            _ = try await ensureValidToken()
            isSignedIn = true
        } catch EmailServiceError.notSignedIn {
            try await signIn(presenting: viewController)
        } catch {
            throw error
        }
    }
    
    func signIn(presenting viewController: UIViewController? = nil) async throws {
        analyticsService.log(event: "gmail_sign_in_started")
        let controller = try await resolvePresentingController(viewController)
        do {
            let credential = try await authenticator.signIn(presenting: controller)
            applyAuthenticatedCredential(credential)
            analyticsService.log(event: "gmail_sign_in_success")
        } catch {
            analyticsService.log(event: "gmail_sign_in_failed", metadata: ["error": error.localizedDescription])
            throw error
        }
    }
    
    func signOut() {
        authenticator.signOut()
        credential = nil
        userEmail = nil
        isSignedIn = false
        latestCandidates = []
        cachedLabelIDs.removeAll()
        do {
            try tokenStore.clear()
        } catch {
            analyticsService.log(event: "gmail_token_clear_failed", metadata: ["error": error.localizedDescription])
        }
    }
    
    func fetchTravelImports(query: String = EmailService.defaultTravelQuery, maxResults: Int = 25) async throws -> [TripImportCandidate] {
        importState = .loading
        analyticsService.log(event: "gmail_import_started", metadata: ["query": query])
        
        do {
            let token = try await ensureValidToken()
            let labelID = try await labelID(named: travelFilterLabelName, token: token, ensure: false)
            let summaries = try await apiClient.listMessages(
                token: token.accessToken,
                labelIds: labelID.map { [$0] } ?? [],
                query: query,
                maxResults: maxResults
            )
            
            let newMessageIDs = deduplicator.filterNewMessageIDs(summaries.map(\.id))
            var candidates: [TripImportCandidate] = []
            for messageID in newMessageIDs {
                do {
                    let message = try await apiClient.fetchMessage(id: messageID, token: token.accessToken)
                    if let candidate = parser.parse(message: message) {
                        candidates.append(candidate)
                    } else {
                        // Skip unparsable messages but mark as processed to avoid repeated attempts
                        deduplicator.markProcessed([messageID])
                    }
                } catch {
                    analyticsService.log(event: "gmail_fetch_message_failed", metadata: ["id": messageID, "error": error.localizedDescription])
                }
            }
            
            latestCandidates = candidates
            importState = .success
            lastImportDate = dateProvider()
            analyticsService.log(event: "gmail_import_completed", metadata: ["count": "\(candidates.count)"])
            return candidates
        } catch {
            importState = .failed(error.localizedDescription)
            analyticsService.log(event: "gmail_import_failed", metadata: ["error": error.localizedDescription])
            throw error
        }
    }
    
    func markProcessed(for candidate: TripImportCandidate) async throws {
        guard !candidate.sourceMessageIDs.isEmpty else { return }
        let token = try await ensureValidToken()
        let labelID = try await labelID(named: processedLabelName, token: token, ensure: true)
        do {
            try await apiClient.applyLabel(labelID: labelID, messageIDs: candidate.sourceMessageIDs, token: token.accessToken)
        } catch {
            analyticsService.log(event: "gmail_apply_label_failed", metadata: ["error": error.localizedDescription])
            throw error
        }
        latestCandidates.removeAll(where: { $0.id == candidate.id })
        deduplicator.markProcessed(candidate.sourceMessageIDs)
        analyticsService.log(event: "gmail_import_candidate_processed", metadata: ["messages": "\(candidate.sourceMessageIDs.count)"])
    }
    
    func dismiss(candidate: TripImportCandidate) {
        latestCandidates.removeAll(where: { $0.id == candidate.id })
        deduplicator.markProcessed(candidate.sourceMessageIDs)
        analyticsService.log(event: "gmail_import_candidate_dismissed", metadata: ["messages": "\(candidate.sourceMessageIDs.count)"])
    }
    
    // MARK: - Private helpers
    
    private func ensureValidToken() async throws -> GmailToken {
        if let credential {
            if credential.token.isValid(at: dateProvider(), tolerance: tokenRefreshTolerance) {
                return credential.token
            }
            do {
                let refreshedToken = try await authenticator.refreshTokenIfNeeded(credential.token)
                let updatedCredential = GmailCredential(email: credential.email, token: refreshedToken)
                applyAuthenticatedCredential(updatedCredential)
                analyticsService.log(event: "gmail_token_refreshed")
                return refreshedToken
            } catch {
                analyticsService.log(event: "gmail_token_refresh_failed", metadata: ["error": error.localizedDescription])
            }
        }
        
        if let storedCredential = try? tokenStore.loadCredential(), storedCredential.token.isValid(at: dateProvider(), tolerance: tokenRefreshTolerance) {
            applyAuthenticatedCredential(storedCredential)
            analyticsService.log(event: "gmail_token_loaded_from_store")
            return storedCredential.token
        }
        
        isSignedIn = false
        throw EmailServiceError.notSignedIn
    }
    
    private func applyAuthenticatedCredential(_ credential: GmailCredential) {
        self.credential = credential
        self.userEmail = credential.email
        self.isSignedIn = true
        do {
            try tokenStore.save(credential)
        } catch {
            analyticsService.log(event: "gmail_token_store_failed", metadata: ["error": error.localizedDescription])
        }
    }
    
    private func labelID(named name: String, token: GmailToken, ensure: Bool) async throws -> String? {
        if let cached = cachedLabelIDs[name] {
            return cached
        }
        let labels = try await apiClient.listLabels(token: token.accessToken)
        if let match = labels.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            cachedLabelIDs[name] = match.id
            return match.id
        }
        guard ensure else { return nil }
        let newLabel = try await apiClient.createLabel(named: name, token: token.accessToken)
        cachedLabelIDs[name] = newLabel.id
        return newLabel.id
    }
    
    private func resolvePresentingController(_ explicit: UIViewController?) async throws -> UIViewController {
        if let explicit { return explicit }
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first(where: { $0.isKeyWindow }),
              let root = window.rootViewController else {
            throw EmailServiceError.missingRootViewController
        }
        return root
    }
    
    private func restorePreviousSignInIfPossible() async {
        do {
            if let restored = try await authenticator.restorePreviousSignIn() {
                applyAuthenticatedCredential(restored)
                analyticsService.log(event: "gmail_restore_success")
            }
        } catch {
            analyticsService.log(event: "gmail_restore_failed", metadata: ["error": error.localizedDescription])
        }
    }
}

// MARK: - Errors & Credentials

enum EmailServiceError: LocalizedError {
    case missingRootViewController
    case notSignedIn
    
    var errorDescription: String? {
        switch self {
        case .missingRootViewController:
            return "Unable to locate a window to present Google Sign-In."
        case .notSignedIn:
            return "Please sign in with your Google account to import travel emails."
        }
    }
}

struct GmailCredential: Codable, Equatable {
    let email: String
    let token: GmailToken
}

struct GmailToken: Codable, Equatable {
    let accessToken: String
    let refreshToken: String?
    let expirationDate: Date
    
    func isValid(at date: Date, tolerance: TimeInterval) -> Bool {
        expirationDate.timeIntervalSince(date) > tolerance
    }
    
    var authorizationHeader: String {
        "Bearer \(accessToken)"
    }
}

// MARK: - Protocols

protocol GmailTokenStore {
    func save(_ credential: GmailCredential) throws
    func loadCredential() throws -> GmailCredential?
    func clear() throws
}

protocol GmailAuthenticating {
    func hasPreviousSignIn() -> Bool
    func restorePreviousSignIn() async throws -> GmailCredential?
    func signIn(presenting viewController: UIViewController) async throws -> GmailCredential
    func refreshTokenIfNeeded(_ token: GmailToken) async throws -> GmailToken
    func signOut()
}

protocol GmailAPIClientProtocol {
    func listMessages(token: String, labelIds: [String], query: String, maxResults: Int) async throws -> [GmailMessageSummary]
    func fetchMessage(id: String, token: String) async throws -> GmailMessage
    func listLabels(token: String) async throws -> [GmailLabel]
    func createLabel(named: String, token: String) async throws -> GmailLabel
    func applyLabel(labelID: String, messageIDs: [String], token: String) async throws
}

protocol EmailParsing {
    func parse(message: GmailMessage) -> TripImportCandidate?
}

protocol EmailDeduplicating {
    func filterNewMessageIDs(_ ids: [String]) -> [String]
    func markProcessed(_ ids: [String])
    func isProcessed(_ id: String) -> Bool
    func reset()
}

// MARK: - Implementations

final class KeychainTokenStore: GmailTokenStore {
    private let service: String
    private let account = "gmail-oauth-token"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    init(service: String) {
        self.service = service
    }
    
    func save(_ credential: GmailCredential) throws {
        let data = try encoder.encode(credential)
        var query = keychainQuery()
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        query[kSecValueData as String] = data
        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let updateStatus = SecItemUpdate(keychainQuery() as CFDictionary, [kSecValueData as String: data] as CFDictionary)
            guard updateStatus == errSecSuccess else { throw KeychainError.unhandled(status: updateStatus) }
        } else if status != errSecSuccess {
            throw KeychainError.unhandled(status: status)
        }
    }
    
    func loadCredential() throws -> GmailCredential? {
        var query = keychainQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess, let data = item as? Data else {
            throw KeychainError.unhandled(status: status)
        }
        return try decoder.decode(GmailCredential.self, from: data)
    }
    
    func clear() throws {
        let status = SecItemDelete(keychainQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandled(status: status)
        }
    }
    
    private func keychainQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

enum KeychainError: Error {
    case unhandled(status: OSStatus)
}

final class GoogleSignInAuthenticator: GmailAuthenticating {
    private var currentUser: GIDGoogleUser?
    private let scopes: [String]
    
    init(scopes: [String]) {
        self.scopes = scopes
    }
    
    func hasPreviousSignIn() -> Bool {
        GIDSignIn.sharedInstance.hasPreviousSignIn()
    }
    
    func restorePreviousSignIn() async throws -> GmailCredential? {
        guard hasPreviousSignIn() else { return nil }
        let result = try await GIDSignIn.sharedInstance.restorePreviousSignIn()
        currentUser = result.user
        return makeCredential(from: result.user)
    }
    
    func signIn(presenting viewController: UIViewController) async throws -> GmailCredential {
        let result = try await GIDSignIn.sharedInstance.signIn(
            withPresenting: viewController,
            hint: nil,
            additionalScopes: scopes
        )
        currentUser = result.user
        return makeCredential(from: result.user)
    }
    
    func refreshTokenIfNeeded(_ token: GmailToken) async throws -> GmailToken {
        guard let currentUser else { return token }
        let refreshedUser = try await currentUser.refreshTokensIfNeeded()
        self.currentUser = refreshedUser
        return makeCredential(from: refreshedUser).token
    }
    
    func signOut() {
        currentUser = nil
        GIDSignIn.sharedInstance.signOut()
    }
    
    private func makeCredential(from user: GIDGoogleUser) -> GmailCredential {
        let email = user.profile?.email ?? ""
        let token = GmailToken(
            accessToken: user.accessToken.tokenString,
            refreshToken: user.refreshToken?.tokenString,
            expirationDate: user.accessToken.expirationDate
        )
        return GmailCredential(email: email, token: token)
    }
}

struct GmailAPIClient: GmailAPIClientProtocol {
    enum APIError: Error {
        case invalidURL
        case invalidResponse
    }
    
    private let session: URLSession
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    func listMessages(token: String, labelIds: [String], query: String, maxResults: Int) async throws -> [GmailMessageSummary] {
        var components = URLComponents(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages")
        var queryItems = [URLQueryItem(name: "maxResults", value: "\(maxResults)")]
        if !labelIds.isEmpty {
            queryItems.append(URLQueryItem(name: "labelIds", value: labelIds.joined(separator: ",")))
        }
        if !query.isEmpty {
            queryItems.append(URLQueryItem(name: "q", value: query))
        }
        components?.queryItems = queryItems
        guard let url = components?.url else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let data = try await perform(request: request)
        let decoded = try JSONDecoder().decode(GmailMessageListResponse.self, from: data)
        return decoded.messages ?? []
    }
    
    func fetchMessage(id: String, token: String) async throws -> GmailMessage {
        guard let url = URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages/\(id)?format=full") else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let data = try await perform(request: request)
        return try JSONDecoder().decode(GmailMessage.self, from: data)
    }
    
    func listLabels(token: String) async throws -> [GmailLabel] {
        guard let url = URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/labels") else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let data = try await perform(request: request)
        let decoded = try JSONDecoder().decode(GmailLabelListResponse.self, from: data)
        return decoded.labels ?? []
    }
    
    func createLabel(named name: String, token: String) async throws -> GmailLabel {
        guard let url = URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/labels") else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload = ["name": name, "labelListVisibility": "labelHide", "messageListVisibility": "show"]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
        let data = try await perform(request: request)
        return try JSONDecoder().decode(GmailLabel.self, from: data)
    }
    
    func applyLabel(labelID: String, messageIDs: [String], token: String) async throws {
        guard let url = URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages/batchModify") else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload = GmailBatchModifyRequest(ids: messageIDs, addLabelIds: [labelID], removeLabelIds: [])
        request.httpBody = try JSONEncoder().encode(payload)
        _ = try await perform(request: request)
    }
    
    private func perform(request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200 ..< 300).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
        return data
    }
}

private struct GmailBatchModifyRequest: Encodable {
    let ids: [String]
    let addLabelIds: [String]
    let removeLabelIds: [String]
}

struct EmailParser: EmailParsing {
    private let isoFormatter: ISO8601DateFormatter
    private let isoWithFraction: ISO8601DateFormatter
    private let displayFormatter: DateFormatter
    private let alternateFormatters: [DateFormatter]
    private let icsParser: ICSParser
    
    init(calendar: Calendar = .current) {
        isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        isoWithFraction = ISO8601DateFormatter()
        isoWithFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .short
        displayFormatter.locale = .current
        displayFormatter.calendar = calendar
        
        let formatter1 = DateFormatter()
        formatter1.dateFormat = "yyyy-MM-dd'T'HH:mm"
        formatter1.locale = .current
        formatter1.calendar = calendar
        
        let formatter2 = DateFormatter()
        formatter2.dateFormat = "yyyy-MM-dd HH:mm"
        formatter2.locale = .current
        formatter2.calendar = calendar
        
        let formatter3 = DateFormatter()
        formatter3.dateFormat = "MMMM d, yyyy h:mm a"
        formatter3.locale = .current
        formatter3.calendar = calendar
        
        alternateFormatters = [formatter1, formatter2, formatter3]
        icsParser = ICSParser(calendar: calendar)
    }
    
    func parse(message: GmailMessage) -> TripImportCandidate? {
        let headers = message.payload.headers ?? []
        let subject = header(named: "Subject", in: headers) ?? "Travel Confirmation"
        let textBody = extractPlainText(from: message.payload) ?? message.snippet ?? ""
        var segments = parseSegmentsFromText(textBody, messageID: message.id)
        segments += parseICSSegments(from: message.payload, messageID: message.id)
        var seen = Set<String>()
        segments = segments.filter { seen.insert($0.fingerprint).inserted }
        guard !segments.isEmpty else { return nil }
        let destination = segments.compactMap { $0.location }.first ?? parseDestination(from: subject) ?? "New Destination"
        let tripName = parseTripName(from: subject, destination: destination)
        return TripImportCandidate(
            tripName: tripName,
            destination: destination,
            segments: segments.sorted(by: { $0.startDate < $1.startDate }),
            sourceMessageIDs: [message.id]
        )
    }
    
    // MARK: - Parsing helpers
    
    private func header(named name: String, in headers: [GmailHeader]) -> String? {
        headers.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }?.value
    }
    
    private func extractPlainText(from payload: GmailPayload) -> String? {
        if let mime = payload.mimeType?.lowercased(), mime.contains("text/plain"), let body = payload.body?.data, let data = decode(body), let string = String(data: data, encoding: .utf8) {
            return string
        }
        for part in payload.parts ?? [] {
            if let text = extractPlainText(from: part) {
                return text
            }
        }
        if let body = payload.body?.data, let data = decode(body), let string = String(data: data, encoding: .utf8) {
            return string
        }
        return nil
    }
    
    private func parseICSSegments(from payload: GmailPayload, messageID: String) -> [TripSegment] {
        var segments: [TripSegment] = []
        if let mime = payload.mimeType?.lowercased(), mime == "text/calendar", let dataString = payload.body?.data, let data = decode(dataString) {
            segments.append(contentsOf: icsParser.segments(from: data, messageID: messageID))
        }
        for part in payload.parts ?? [] {
            segments.append(contentsOf: parseICSSegments(from: part, messageID: messageID))
        }
        return segments
    }
    
    private func parseSegmentsFromText(_ text: String, messageID: String) -> [TripSegment] {
        let normalizedBlocks = text.components(separatedBy: "\n\n")
        var segments: [TripSegment] = []
        for block in normalizedBlocks {
            let normalized = block.lowercased()
            if normalized.contains("flight") {
                if let segment = parseFlightBlock(block, messageID: messageID) {
                    segments.append(segment)
                }
            } else if normalized.contains("hotel") {
                if let segment = parseHotelBlock(block, messageID: messageID) {
                    segments.append(segment)
                }
            } else if normalized.contains("rental") || normalized.contains("car rental") {
                if let segment = parseRentalBlock(block, messageID: messageID) {
                    segments.append(segment)
                }
            }
        }
        return segments
    }
    
    private func parseFlightBlock(_ block: String, messageID: String) -> TripSegment? {
        let fields = dictionary(from: block)
        guard let flightNumber = fields[firstMatching: ["flight", "flight number"]],
              let departureString = fields[firstMatching: ["departure", "depart"]],
              let arrivalString = fields[firstMatching: ["arrival", "arrive"]],
              let departureDate = parseDate(from: departureString),
              let arrivalDate = parseDate(from: arrivalString) else {
            return nil
        }
        let originValue = fields[firstMatching: ["from", "origin"]]
        let destinationValue = fields[firstMatching: ["to", "destination"]]
        let origin = parseLocation(originValue)
        let destination = parseLocation(destinationValue)
        var metadata: [String: String] = [
            "flightNumber": flightNumber.stripPrefix("Flight")
        ]
        if let originText = origin.text {
            metadata["origin"] = originText
        }
        if let destinationText = destination.text {
            metadata["destination"] = destinationText
        }
        if let originCode = origin.code {
            metadata["departureAirport"] = originCode
        }
        if let destinationCode = destination.code {
            metadata["arrivalAirport"] = destinationCode
        }
        metadata["departure"] = displayFormatter.string(from: departureDate)
        metadata["arrival"] = displayFormatter.string(from: arrivalDate)
        let title = "Flight \(flightNumber.stripPrefix("Flight"))"
        let location = destination.text ?? destinationValue ?? originValue
        return TripSegment(
            type: .flight,
            title: title,
            startDate: departureDate,
            endDate: arrivalDate,
            location: location,
            metadata: metadata,
            sourceMessageIDs: [messageID]
        )
    }
    
    private func parseHotelBlock(_ block: String, messageID: String) -> TripSegment? {
        let fields = dictionary(from: block)
        guard let hotelName = fields[firstMatching: ["hotel", "property"]],
              let checkInString = fields[firstMatching: ["check-in", "check in"]],
              let checkOutString = fields[firstMatching: ["check-out", "check out"]],
              let checkInDate = parseDate(from: checkInString),
              let checkOutDate = parseDate(from: checkOutString) else {
            return nil
        }
        let location = fields[firstMatching: ["location", "city", "address"]]
        var metadata: [String: String] = [
            "checkIn": displayFormatter.string(from: checkInDate),
            "checkOut": displayFormatter.string(from: checkOutDate)
        ]
        if let location {
            metadata["location"] = location
        }
        return TripSegment(
            type: .hotel,
            title: hotelName,
            startDate: checkInDate,
            endDate: checkOutDate,
            location: location,
            metadata: metadata,
            sourceMessageIDs: [messageID]
        )
    }
    
    private func parseRentalBlock(_ block: String, messageID: String) -> TripSegment? {
        let fields = dictionary(from: block)
        guard let rentalCompany = fields[firstMatching: ["rental", "company"]],
              let pickupString = fields[firstMatching: ["pick-up", "pickup"]],
              let dropoffString = fields[firstMatching: ["drop-off", "dropoff"]],
              let pickupDate = parseDate(from: pickupString),
              let dropoffDate = parseDate(from: dropoffString) else {
            return nil
        }
        let pickupLocation = fields[firstMatching: ["pickup location", "pick-up location", "pickup"]]
        let dropoffLocation = fields[firstMatching: ["dropoff location", "drop-off location", "dropoff"]]
        var metadata: [String: String] = [
            "pickup": displayFormatter.string(from: pickupDate),
            "dropoff": displayFormatter.string(from: dropoffDate)
        ]
        if let pickupLocation {
            metadata["pickupLocation"] = pickupLocation
        }
        if let dropoffLocation {
            metadata["dropoffLocation"] = dropoffLocation
        }
        return TripSegment(
            type: .rental,
            title: rentalCompany,
            startDate: pickupDate,
            endDate: dropoffDate,
            location: dropoffLocation ?? pickupLocation,
            metadata: metadata,
            sourceMessageIDs: [messageID]
        )
    }
    
    private func dictionary(from block: String) -> [String: String] {
        var result: [String: String] = [:]
        block
            .split(separator: "\n")
            .forEach { line in
                let parts = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: true)
                guard parts.count == 2 else { return }
                let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                if !key.isEmpty {
                    result[key] = value
                }
            }
        return result
    }
    
    private func parseDate(from string: String) -> Date? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if let date = isoFormatter.date(from: trimmed) { return date }
        if let date = isoWithFraction.date(from: trimmed) { return date }
        for formatter in alternateFormatters {
            if let date = formatter.date(from: trimmed) {
                return date
            }
        }
        return nil
    }
    
    private func parseLocation(_ value: String?) -> (text: String?, code: String?) {
        guard let value else { return (nil, nil) }
        if let openParen = value.firstIndex(of: "("), let closeParen = value.firstIndex(of: ")"), openParen < closeParen {
            let city = value[..<openParen].trimmingCharacters(in: .whitespacesAndNewlines)
            let code = value[value.index(after: openParen)..<closeParen].trimmingCharacters(in: .whitespacesAndNewlines)
            return (city.isEmpty ? nil : String(city), code.isEmpty ? nil : String(code))
        }
        return (value.trimmingCharacters(in: .whitespacesAndNewlines), nil)
    }
    
    private func parseDestination(from subject: String) -> String? {
        let lower = subject.lowercased()
        if let range = lower.range(of: " to ") {
            let substring = subject[range.upperBound...]
            if let dashRange = substring.range(of: " - ") {
                return String(substring[..<dashRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return substring.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let range = lower.range(of: " for ") {
            return subject[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }
    
    private func parseTripName(from subject: String, destination: String) -> String {
        if subject.isEmpty { return "Trip to \(destination)" }
        return subject
    }
    
    private func decode(_ string: String) -> Data? {
        var base64 = string.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        let padding = base64.count % 4
        if padding > 0 {
            base64.append(String(repeating: "=", count: 4 - padding))
        }
        return Data(base64Encoded: base64)
    }
}

private extension Dictionary where Key == String, Value == String {
    subscript(firstMatching keys: [String]) -> String? {
        for key in keys {
            if let value = self[key] {
                return value
            }
        }
        return nil
    }
}

private extension String {
    func stripPrefix(_ prefix: String) -> String {
        guard lowercased().hasPrefix(prefix.lowercased()) else { return self }
        let index = self.index(startIndex, offsetBy: prefix.count)
        return String(self[index...]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct ICSParser {
    private let calendar: Calendar
    private let isoFormatter: ISO8601DateFormatter
    
    init(calendar: Calendar = .current) {
        self.calendar = calendar
        self.isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds, .withTimeZone]
    }
    
    func segments(from data: Data, messageID: String) -> [TripSegment] {
        guard let content = String(data: data, encoding: .utf8) else { return [] }
        let events = content.components(separatedBy: "BEGIN:VEVENT")
        var segments: [TripSegment] = []
        for eventSection in events {
            guard let endRange = eventSection.range(of: "END:VEVENT") else { continue }
            let eventBody = String(eventSection[..<endRange.lowerBound])
            let fields = parseFields(eventBody)
            guard let summary = fields["SUMMARY"],
                  let dtStartString = fields["DTSTART"],
                  let dtEndString = fields["DTEND"],
                  let startDate = parse(dateString: dtStartString),
                  let endDate = parse(dateString: dtEndString) else {
                continue
            }
            let location = fields["LOCATION"]
            let segmentType = TripSegmentType.from(summary: summary)
            var metadata = fields.reduce(into: [String: String]()) { result, pair in
                result[pair.key.lowercased()] = pair.value
            }
            metadata["summary"] = summary
            segments.append(
                TripSegment(
                    type: segmentType,
                    title: summary,
                    startDate: startDate,
                    endDate: endDate,
                    location: location,
                    metadata: metadata,
                    sourceMessageIDs: [messageID]
                )
            )
        }
        return segments
    }
    
    private func parseFields(_ text: String) -> [String: String] {
        var result: [String: String] = [:]
        text
            .split(separator: "\n")
            .forEach { line in
                let parts = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: true)
                guard parts.count == 2 else { return }
                let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                if !key.isEmpty {
                    result[key] = value
                }
            }
        return result
    }
    
    private func parse(dateString: String) -> Date? {
        if let date = isoFormatter.date(from: dateString) {
            return date
        }
        if dateString.count == 15 || dateString.count == 16 {
            // Handle basic format: YYYYMMDDTHHMMSSZ
            let formatter = DateFormatter()
            formatter.calendar = calendar
            formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            if let date = formatter.date(from: dateString) {
                return date
            }
        }
        return nil
    }
}

extension TripSegmentType {
    static func from(summary: String) -> TripSegmentType {
        let lower = summary.lowercased()
        if lower.contains("flight") || lower.contains("air") {
            return .flight
        }
        if lower.contains("hotel") || lower.contains("stay") {
            return .hotel
        }
        if lower.contains("rental") || lower.contains("car") {
            return .rental
        }
        return .event
    }
}

final class EmailDeduplicator: EmailDeduplicating {
    private let defaults: UserDefaults
    private let key = "com.smarttripplanner.gmail.processedMessageIDs"
    
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }
    
    func filterNewMessageIDs(_ ids: [String]) -> [String] {
        ids.filter { !isProcessed($0) }
    }
    
    func markProcessed(_ ids: [String]) {
        guard !ids.isEmpty else { return }
        var set = processedIDs
        for id in ids {
            set.insert(id)
        }
        defaults.set(Array(set), forKey: key)
    }
    
    func isProcessed(_ id: String) -> Bool {
        processedIDs.contains(id)
    }
    
    func reset() {
        defaults.removeObject(forKey: key)
    }
    
    private var processedIDs: Set<String> {
        let array = defaults.array(forKey: key) as? [String] ?? []
        return Set(array)
    }
}

// MARK: - Gmail API Models

struct GmailMessageListResponse: Decodable {
    let messages: [GmailMessageSummary]?
}

struct GmailMessageSummary: Decodable, Hashable {
    let id: String
    let threadId: String
}

struct GmailMessage: Decodable {
    let id: String
    let threadId: String
    let labelIds: [String]?
    let snippet: String?
    let payload: GmailPayload
    let internalDate: String?
}

struct GmailPayload: Decodable {
    let partId: String?
    let mimeType: String?
    let filename: String?
    let headers: [GmailHeader]?
    let body: GmailBody?
    let parts: [GmailPayload]?
}

struct GmailBody: Decodable {
    let size: Int?
    let data: String?
}

struct GmailHeader: Decodable {
    let name: String
    let value: String
}

struct GmailLabelListResponse: Decodable {
    let labels: [GmailLabel]?
}

struct GmailLabel: Decodable {
    let id: String
    let name: String
}
