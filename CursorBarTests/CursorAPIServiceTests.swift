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
