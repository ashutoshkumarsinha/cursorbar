import Foundation

enum CursorAPIError: LocalizedError {
    case missingToken
    case unauthorized
    case invalidResponse
    case httpError(Int)
    case decodingFailed(Error)
    case invalidBaseURL

    var errorDescription: String? {
        switch self {
        case .missingToken:
            return "No session token configured."
        case .unauthorized:
            return "Session expired. Re-authenticate with a fresh WorkosCursorSessionToken."
        case .invalidResponse:
            return "Invalid response from Cursor API."
        case .httpError(let code):
            return "HTTP error \(code)."
        case .decodingFailed(let error):
            return "Failed to decode usage data: \(error.localizedDescription)"
        case .invalidBaseURL:
            return "Invalid API base URL in configuration."
        }
    }
}

/// Lightweight HTTP client mimicking authorized browser requests to cursor.com.
final class CursorAPIService {
    static let shared = CursorAPIService()

    private let baseURL: URL
    private let userAgent: String
    private let session: URLSession

    init(config: AppConfig = .default, session: URLSession = .shared) {
        self.baseURL = URL(string: config.apiBaseURL) ?? URL(string: AppConfig.default.apiBaseURL)!
        self.userAgent = config.userAgent
        self.session = session
    }

    func fetchUsage(sessionToken: String) async throws -> UsageResponse {
        var request = URLRequest(url: baseURL)
        request.httpMethod = "GET"
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(
            "WorkosCursorSessionToken=\(sessionToken)",
            forHTTPHeaderField: "Cookie"
        )

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw CursorAPIError.invalidResponse
        }

        switch http.statusCode {
        case 200:
            break
        case 401, 403:
            throw CursorAPIError.unauthorized
        default:
            throw CursorAPIError.httpError(http.statusCode)
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(UsageResponse.self, from: data)
        } catch {
            throw CursorAPIError.decodingFailed(error)
        }
    }
}
