import Foundation

struct GmailMessageIdentifier: Decodable {
    let id: String
    let threadId: String
}

struct GmailMessageListResponse: Decodable {
    let messages: [GmailMessageIdentifier]?
    let nextPageToken: String?
}

struct GmailHeader: Decodable {
    let name: String
    let value: String
}

struct GmailBody: Decodable {
    let size: Int
    let data: String?
}

struct GmailPayload: Decodable {
    let partId: String?
    let mimeType: String?
    let filename: String?
    let headers: [GmailHeader]?
    let body: GmailBody?
    let parts: [GmailPayload]?
}

struct GmailMessage: Decodable {
    let id: String
    let threadId: String
    let labelIds: [String]?
    let snippet: String?
    let payload: GmailPayload?
    let sizeEstimate: Int?
    let historyId: String?
    let internalDate: String?
}

protocol GmailClient {
    func listMessageIdentifiers(accessToken: String,
                                query: String?,
                                maxResults: Int) async throws -> GmailMessageListResponse
    func fetchMessage(accessToken: String, id: String) async throws -> GmailMessage
}

enum GmailClientError: LocalizedError {
    case invalidResponse
    case httpError(code: Int, message: String)
    case decodingFailed
    case requestFailed(Error)
    case rateLimited(retryAfter: TimeInterval)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from Gmail API"
        case let .httpError(code, message):
            return "Gmail API error (\(code)): \(message)"
        case .decodingFailed:
            return "Failed to decode Gmail response"
        case let .requestFailed(error):
            return error.localizedDescription
        case .rateLimited:
            return "Gmail API rate limit exceeded"
        }
    }
}

final class DefaultGmailClient: GmailClient {
    private let session: URLSession
    private let decoder: JSONDecoder
    private let baseURL = URL(string: "https://gmail.googleapis.com/gmail/v1/users/me")!
    
    init(session: URLSession = .shared, decoder: JSONDecoder = JSONDecoder()) {
        self.session = session
        self.decoder = decoder
    }
    
    func listMessageIdentifiers(accessToken: String,
                                query: String?,
                                maxResults: Int) async throws -> GmailMessageListResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("messages"), resolvingAgainstBaseURL: false)
        var queryItems: [URLQueryItem] = []
        if let query, !query.isEmpty {
            queryItems.append(URLQueryItem(name: "q", value: query))
        }
        queryItems.append(URLQueryItem(name: "maxResults", value: String(maxResults)))
        components?.queryItems = queryItems
        guard let url = components?.url else {
            throw GmailClientError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await execute(request: request)
        do {
            return try decoder.decode(GmailMessageListResponse.self, from: data)
        } catch {
            throw GmailClientError.decodingFailed
        }
    }
    
    func fetchMessage(accessToken: String, id: String) async throws -> GmailMessage {
        var components = URLComponents(url: baseURL.appendingPathComponent("messages/\(id)"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "format", value: "full")]
        guard let url = components?.url else {
            throw GmailClientError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, _) = try await execute(request: request)
        do {
            return try decoder.decode(GmailMessage.self, from: data)
        } catch {
            throw GmailClientError.decodingFailed
        }
    }
    
    private func execute(request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw GmailClientError.invalidResponse
            }
            switch httpResponse.statusCode {
            case 200...299:
                return (data, httpResponse)
            case 429:
                let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After").flatMap { Double($0) } ?? 60
                throw GmailClientError.rateLimited(retryAfter: retryAfter)
            default:
                let message = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw GmailClientError.httpError(code: httpResponse.statusCode, message: message)
            }
        } catch let error as GmailClientError {
            throw error
        } catch {
            throw GmailClientError.requestFailed(error)
        }
    }
}

extension GmailPayload {
    func header(named name: String) -> String? {
        headers?.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }?.value
    }
    
    func bodyData() -> Data? {
        if let data = body?.data, let decoded = Data(base64URLEncoded: data) {
            return decoded
        }
        if let parts {
            for part in parts {
                if let mimeType = part.mimeType?.lowercased(), mimeType == "text/plain",
                   let data = part.body?.data,
                   let decoded = Data(base64URLEncoded: data) {
                    return decoded
                }
            }
            for part in parts {
                if let data = part.body?.data, let decoded = Data(base64URLEncoded: data) {
                    return decoded
                }
            }
        }
        return nil
    }
}

extension Data {
    init?(base64URLEncoded string: String) {
        var base64 = string.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        let padding = 4 - base64.count % 4
        if padding < 4 {
            base64.append(String(repeating: "=", count: padding))
        }
        guard let data = Data(base64Encoded: base64) else {
            return nil
        }
        self = data
    }
}
