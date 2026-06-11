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
        let cookie = SessionTokenNormalizer.cookieValue(from: sessionToken)
        let bearer = SessionTokenNormalizer.bearerToken(from: sessionToken)

        async let summaryResult = fetchSummaryIfPossible(cookie: cookie)
        async let legacyResult = fetchLegacyIfPossible(cookie: cookie)
        async let periodResult = fetchPeriodIfPossible(bearer: bearer)

        let (summary, summaryError) = await summaryResult
        let legacy = await legacyResult
        let period = await periodResult

        if summary != nil || legacy != nil || period != nil {
            return UsageResponseMapper.from(
                summary: summary ?? .empty,
                period: period,
                legacy: legacy
            )
        }

        if let summaryError {
            throw summaryError
        }
        throw CursorAPIError.noUsageData
    }

    // MARK: - usage-summary

    private func fetchSummaryIfPossible(cookie: String) async -> (UsageSummaryResponse?, CursorAPIError?) {
        do {
            let summary = try await get(
                url: summaryURL,
                cookie: cookie,
                as: UsageSummaryResponse.self
            )
            return (summary, nil)
        } catch let error as CursorAPIError {
            return (nil, error)
        } catch {
            return (nil, .decodingFailed(error))
        }
    }

    // MARK: - legacy /api/usage (model breakdown + enterprise requests)

    private func fetchLegacyIfPossible(cookie: String) async -> LegacyUsageResponse? {
        try? await get(
            url: legacyUsageURL,
            cookie: cookie,
            as: LegacyUsageResponse.self
        )
    }

    // MARK: - Connect RPC spend plans

    private func fetchPeriodIfPossible(bearer: String?) async -> CurrentPeriodUsageResponse? {
        guard let bearer, !bearer.isEmpty else { return nil }

        var request = URLRequest(url: periodUsageURL)
        request.httpMethod = "POST"
        request.httpBody = Data("{}".utf8)
        request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("1", forHTTPHeaderField: "Connect-Protocol-Version")
        request.setValue("https://cursor.com", forHTTPHeaderField: "Origin")
        request.setValue("https://cursor.com/dashboard/usage", forHTTPHeaderField: "Referer")

        do {
            let (data, response) = try await session.data(for: request)
            try validateHTTP(response)
            try validatePayload(data)
            return try JSONDecoder().decode(CurrentPeriodUsageResponse.self, from: data)
        } catch {
            return nil
        }
    }

    // MARK: - HTTP helpers

    private func get<T: Decodable>(
        url: URL,
        cookie: String,
        as type: T.Type
    ) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        applyCookieAuth(&request, cookie: cookie)

        let (data, response) = try await session.data(for: request)
        try validateHTTP(response)
        try validatePayload(data)

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw CursorAPIError.decodingFailed(error)
        }
    }

    private func applyCookieAuth(_ request: inout URLRequest, cookie: String) {
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(
            "WorkosCursorSessionToken=\(cookie)",
            forHTTPHeaderField: "Cookie"
        )
        request.setValue("https://cursor.com/dashboard/usage", forHTTPHeaderField: "Referer")
    }

    private func validatePayload(_ data: Data) throws {
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            object["error"] != nil
        else {
            return
        }
        throw CursorAPIError.unauthorized
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
        var normalized = configured
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "www.cursor.com", with: "cursor.com")

        if normalized.contains("usage-summary") {
            // Already on the current endpoint — do not rewrite (avoids usage-summary-summary).
        } else if normalized.hasSuffix("/api/usage") {
            normalized = String(normalized.dropLast("/api/usage".count)) + "/api/usage-summary"
        } else if normalized.isEmpty {
            normalized = fallback
        }

        if let url = URL(string: normalized) {
            return url
        }
        return URL(string: fallback)!
    }
}

// MARK: - Session token normalization

enum SessionTokenNormalizer {
    /// Cookie value for cursor.com REST endpoints (`userId%3A%3A<jwt>`).
    static func cookieValue(from raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.contains("%3A%3A") {
            return trimmed
        }
        if trimmed.contains("::") {
            return trimmed.replacingOccurrences(of: "::", with: "%3A%3A")
        }
        if trimmed.hasPrefix("eyJ"), let userID = jwtUserID(from: trimmed) {
            return "\(userID)%3A%3A\(trimmed)"
        }
        return trimmed
    }

    /// JWT for api2.cursor.sh Connect RPC endpoints.
    static func bearerToken(from raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let range = trimmed.range(of: "%3A%3A") {
            return String(trimmed[range.upperBound...])
        }
        if let range = trimmed.range(of: "::") {
            return String(trimmed[range.upperBound...])
        }
        if trimmed.hasPrefix("eyJ") {
            return trimmed
        }
        return nil
    }

    private static func jwtUserID(from jwt: String) -> String? {
        let segments = jwt.split(separator: ".")
        guard segments.count >= 2 else { return nil }

        var payload = String(segments[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        payload += String(repeating: "=", count: (4 - payload.count % 4) % 4)
        guard
            let data = Data(base64Encoded: payload),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let subject = json["sub"] as? String
        else {
            return nil
        }

        if let pipe = subject.lastIndex(of: "|") {
            return String(subject[subject.index(after: pipe)...])
        }
        return subject
    }
}
