import Foundation

actor APIClient {
    private let baseURL = URL(string: "https://api.appstoreconnect.apple.com")!
    private var cachedToken: String?
    private var tokenExpiration: Date?

    private let issuerID: String
    private let keyID: String
    private let privateKey: String

    init(credentials: Credentials) {
        self.issuerID = credentials.issuerID
        self.keyID = credentials.keyID
        self.privateKey = credentials.privateKey
    }

    private func getToken() throws -> String {
        if let token = cachedToken, let exp = tokenExpiration, Date() < exp {
            return token
        }
        let token = try JWTService.generateToken(
            issuerID: issuerID,
            keyID: keyID,
            privateKeyPEM: privateKey
        )
        cachedToken = token
        tokenExpiration = Date().addingTimeInterval(1080) // Refresh 2 min before expiry
        return token
    }

    func get<T: Decodable & Sendable>(path: String, queryItems: [URLQueryItem]? = nil) async throws -> T {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        components.queryItems = queryItems
        guard let url = components.url else {
            throw APIError.invalidResponse
        }
        return try await performRequest(url: url)
    }

    func get<T: Decodable & Sendable>(url: URL) async throws -> T {
        return try await performRequest(url: url)
    }

    func post<Body: Encodable & Sendable, T: Decodable & Sendable>(
        path: String, body: Body
    ) async throws -> T {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(try getToken())", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)
        return try decodeResponse(data)
    }

    func getData(url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(try getToken())", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)
        return data
    }

    private func performRequest<T: Decodable & Sendable>(url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(try getToken())", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)
        return try decodeResponse(data)
    }

    private func decodeResponse<T: Decodable>(_ data: Data) throws -> T {
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        switch http.statusCode {
        case 200...299:
            return
        case 401:
            throw APIError.unauthorized
        case 403:
            throw APIError.forbidden
        case 404:
            throw APIError.notFound
        case 429:
            throw APIError.rateLimited
        default:
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.httpError(statusCode: http.statusCode, message: message)
        }
    }
}

nonisolated enum APIError: LocalizedError {
    case invalidResponse
    case unauthorized
    case forbidden
    case notFound
    case rateLimited
    case httpError(statusCode: Int, message: String)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid server response."
        case .unauthorized:
            return "Invalid credentials. Please check your API key configuration."
        case .forbidden:
            return "Access denied. Your API key may lack required permissions."
        case .notFound:
            return "Resource not found."
        case .rateLimited:
            return "Rate limit exceeded. Please wait a moment and try again."
        case .httpError(let code, _):
            return "Server error (HTTP \(code))."
        case .decodingError(let error):
            return "Failed to parse response: \(error.localizedDescription)"
        }
    }
}
