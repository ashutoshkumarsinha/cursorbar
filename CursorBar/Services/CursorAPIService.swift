import Foundation

enum CursorAPIError: LocalizedError {
    case missingToken
    case unauthorized
    case invalidResponse
    case httpError(Int)
    case decodingFailed(Error)
    case invalidBaseURL
    case noUsageData

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
        case .noUsageData:
            return "Cursor returned no recognizable usage data."
        }
    }
}

/// Lightweight HTTP client mimicking authorized browser requests to cursor.com.
final class CursorAPIService {
    static let shared = CursorAPIService()

    private let summaryURL: URL
    private let legacyUsageURL: URL
    private let periodUsageURL: URL
    private let userAgent: String
    private let session: URLSession

    init(config: AppConfig = .default, session: URLSession = .shared) {
        self.summaryURL = Self.resolveURL(config.apiBaseURL, fallback: "https://cursor.com/api/usage-summary")
        self.legacyUsageURL = URL(string: "https://cursor.com/api/usage")!
        self.periodUsageURL = URL(string: "https://api2.cursor.sh/aiserver.v1.DashboardService/GetCurrentPeriodUsage")!
        self.userAgent = config.userAgent
        self.session = session
    }

    func fetchUsage(sessionToken: String) async throws -> UsageResponse {
        async let summaryTask = fetchSummary(sessionToken: sessionToken)
        async let legacyTask = fetchLegacyUsage(sessionToken: sessionToken)
        async let periodTask = fetchCurrentPeriodUsage(sessionToken: sessionToken)

        let summary = try await summaryTask
        let legacy = try? await legacyTask
        let period = try? await periodTask

        return UsageResponseMapper.from(summary: summary, period: period, legacy: legacy)
    }

    // MARK: - usage-summary

    private func fetchSummary(sessionToken: String) async throws -> UsageSummaryResponse {
        try await get(
            url: summaryURL,
            sessionToken: sessionToken,
            as: UsageSummaryResponse.self
        )
    }

    // MARK: - legacy /api/usage (model breakdown + enterprise requests)

    private func fetchLegacyUsage(sessionToken: String) async throws -> LegacyUsageResponse {
        try await get(
            url: legacyUsageURL,
            sessionToken: sessionToken,
            as: LegacyUsageResponse.self
        )
    }

    // MARK: - Connect RPC spend plans

    private func fetchCurrentPeriodUsage(sessionToken: String) async throws -> CurrentPeriodUsageResponse {
        var request = URLRequest(url: periodUsageURL)
        request.httpMethod = "POST"
        request.httpBody = Data("{}".utf8)
        applyAuthHeaders(&request, sessionToken: sessionToken)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("1", forHTTPHeaderField: "Connect-Protocol-Version")
        request.setValue("https://cursor.com", forHTTPHeaderField: "Origin")
        request.setValue("https://cursor.com/dashboard/usage", forHTTPHeaderField: "Referer")

        let (data, response) = try await session.data(for: request)
        try validateHTTP(response)

        do {
            return try JSONDecoder().decode(CurrentPeriodUsageResponse.self, from: data)
        } catch {
            throw CursorAPIError.decodingFailed(error)
        }
    }

    // MARK: - HTTP helpers

    private func get<T: Decodable>(
        url: URL,
        sessionToken: String,
        as type: T.Type
    ) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        applyAuthHeaders(&request, sessionToken: sessionToken)

        let (data, response) = try await session.data(for: request)
        try validateHTTP(response)

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw CursorAPIError.decodingFailed(error)
        }
    }

    private func applyAuthHeaders(_ request: inout URLRequest, sessionToken: String) {
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(
            "WorkosCursorSessionToken=\(sessionToken)",
            forHTTPHeaderField: "Cookie"
        )
        request.setValue("https://cursor.com/dashboard/usage", forHTTPHeaderField: "Referer")
    }

    private func validateHTTP(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw CursorAPIError.invalidResponse
        }

        switch http.statusCode {
        case 200:
            return
        case 401, 403:
            throw CursorAPIError.unauthorized
        default:
            throw CursorAPIError.httpError(http.statusCode)
        }
    }

    private static func resolveURL(_ configured: String, fallback: String) -> URL {
        let normalized = configured
            .replacingOccurrences(of: "www.cursor.com", with: "cursor.com")
            .replacingOccurrences(of: "/api/usage", with: "/api/usage-summary")

        if let url = URL(string: normalized), normalized.contains("usage-summary") {
            return url
        }
        return URL(string: fallback)!
    }
}
