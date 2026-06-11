import XCTest
@testable import CursorBar

final class CursorAPIServiceTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        super.tearDown()
    }

    func testFetchUsageUsesUsageSummaryEndpoint() async throws {
        let summaryData = try loadFixture(named: "usage-summary")
        let legacyData = Data("{}".utf8)
        var requestedPaths: [String] = []

        MockURLProtocol.requestHandler = { request in
            requestedPaths.append(request.url?.path ?? "")
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            if request.url?.path.contains("usage-summary") == true {
                return (response, summaryData)
            }
            if request.url?.path.contains("/api/usage") == true {
                return (response, legacyData)
            }
            if request.url?.host == "api2.cursor.sh" {
                return (response, Data("{}".utf8))
            }
            return (response, summaryData)
        }

        let config = AppConfig(
            refreshIntervalMinutes: 15,
            pauseOnSleep: true,
            syncOnWake: true,
            displaySpending: false,
            apiBaseURL: "https://cursor.com/api/usage-summary",
            userAgent: "CursorBar-Test/1.0",
            gaugeThresholds: .default,
            loggingLevel: "info"
        )

        let api = CursorAPIService(config: config, session: MockURLSessionFactory.make())
        let usage = try await api.fetchUsage(sessionToken: "test-token")

        XCTAssertEqual(usage.subscriptionPlan, "Pro")
        XCTAssertEqual(usage.fastRequestsRemaining, 350)
        XCTAssertTrue(requestedPaths.contains { $0.contains("usage-summary") })
    }

    func testSummaryURLDoesNotDoubleSuffix() async throws {
        let summaryData = try loadFixture(named: "usage-summary")
        var requestedPaths: [String] = []

        MockURLProtocol.requestHandler = { request in
            requestedPaths.append(request.url?.path ?? "")
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, summaryData)
        }

        let config = AppConfig(
            refreshIntervalMinutes: 15,
            pauseOnSleep: true,
            syncOnWake: true,
            displaySpending: false,
            apiBaseURL: "https://cursor.com/api/usage-summary",
            userAgent: "CursorBar-Test/1.0",
            gaugeThresholds: .default,
            loggingLevel: "info"
        )

        let api = CursorAPIService(config: config, session: MockURLSessionFactory.make())
        _ = try await api.fetchUsage(sessionToken: "user_test%3A%3AeyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ0ZXN0In0.sig")

        XCTAssertTrue(requestedPaths.contains("/api/usage-summary"))
        XCTAssertFalse(requestedPaths.contains { $0.contains("usage-summary-summary") })
    }

    func testNotAuthenticatedJSONMapsToUnauthorized() async {
        let body = Data(
            #"{"error":"not_authenticated","description":"The user does not have an active session or is not authenticated"}"#.utf8
        )

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, body)
        }

        let api = CursorAPIService(session: MockURLSessionFactory.make())

        do {
            _ = try await api.fetchUsage(sessionToken: "bad-token")
            XCTFail("Expected unauthorized error")
        } catch let error as CursorAPIError {
            XCTAssertEqual(error, .unauthorized)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testJWTOnlyTokenNormalizesCookieAndBearer() async throws {
        let summaryData = try loadFixture(named: "usage-summary")
        var cookieHeader: String?
        var authorizationHeader: String?

        MockURLProtocol.requestHandler = { request in
            if request.url?.host?.contains("cursor.com") == true {
                cookieHeader = request.value(forHTTPHeaderField: "Cookie")
            }
            if request.url?.host == "api2.cursor.sh" {
                authorizationHeader = request.value(forHTTPHeaderField: "Authorization")
            }
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            if request.url?.host == "api2.cursor.sh" {
                return (response, Data("{}".utf8))
            }
            return (response, summaryData)
        }

        let jwt = makeTestJWT(sub: "google-oauth2|user_abc123")
        let api = CursorAPIService(session: MockURLSessionFactory.make())
        _ = try await api.fetchUsage(sessionToken: jwt)

        XCTAssertEqual(
            cookieHeader,
            "WorkosCursorSessionToken=user_abc123%3A%3A\(jwt)"
        )
        XCTAssertEqual(authorizationHeader, "Bearer \(jwt)")
    }

    func testUnauthorizedMapsToError() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 403,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        let api = CursorAPIService(session: MockURLSessionFactory.make())

        do {
            _ = try await api.fetchUsage(sessionToken: "bad-token")
            XCTFail("Expected unauthorized error")
        } catch let error as CursorAPIError {
            XCTAssertEqual(error, .unauthorized)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func makeTestJWT(sub: String) -> String {
        func b64(_ value: String) -> String {
            Data(value.utf8)
                .base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
        }

        let header = b64(#"{"alg":"none","typ":"JWT"}"#)
        let payload = b64(#"{"sub":"\#(sub)"}"#)
        return "\(header).\(payload).signature"
    }

    private func loadFixture(named name: String) throws -> Data {
        let bundle = Bundle(for: CursorAPIServiceTests.self)
        let url = bundle.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")
            ?? bundle.url(forResource: name, withExtension: "json")
        guard let url else {
            throw XCTSkip("Fixture \(name).json not in test bundle")
        }
        return try Data(contentsOf: url)
    }
}

extension CursorAPIError: Equatable {
    public static func == (lhs: CursorAPIError, rhs: CursorAPIError) -> Bool {
        switch (lhs, rhs) {
        case (.missingToken, .missingToken),
             (.unauthorized, .unauthorized),
             (.invalidResponse, .invalidResponse),
             (.invalidBaseURL, .invalidBaseURL),
             (.noUsageData, .noUsageData):
            return true
        case (.httpError(let l), .httpError(let r)):
            return l == r
        case (.decodingFailed, .decodingFailed):
            return true
        default:
            return false
        }
    }
}
