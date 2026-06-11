import XCTest
@testable import CursorBar

final class CursorAPIServiceTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        super.tearDown()
    }

    func testFetchUsageSendsConfiguredHeaders() async throws {
        let data = try loadFixture(named: "usage")
        var capturedRequest: URLRequest?

        MockURLProtocol.requestHandler = { request in
            capturedRequest = request
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, data)
        }

        let config = AppConfig(
            refreshIntervalMinutes: 15,
            pauseOnSleep: true,
            syncOnWake: true,
            displaySpending: false,
            apiBaseURL: "https://www.cursor.com/api/usage",
            userAgent: "CursorBar-Test/1.0",
            gaugeThresholds: .default,
            loggingLevel: "info"
        )

        let api = CursorAPIService(config: config, session: MockURLSessionFactory.make())
        let usage = try await api.fetchUsage(sessionToken: "test-token")

        XCTAssertEqual(usage.subscriptionPlan, "Pro")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "User-Agent"), "CursorBar-Test/1.0")
        XCTAssertEqual(
            capturedRequest?.value(forHTTPHeaderField: "Cookie"),
            "WorkosCursorSessionToken=test-token"
        )
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
             (.invalidBaseURL, .invalidBaseURL):
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
