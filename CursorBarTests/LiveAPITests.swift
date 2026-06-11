import XCTest
@testable import CursorBar

final class LiveAPITests: XCTestCase {
    func testLiveUsageEndpointWithSessionToken() async throws {
        guard let token = ProcessInfo.processInfo.environment["CURSORBAR_SESSION_TOKEN"],
              !token.isEmpty else {
            throw XCTSkip("Set CURSORBAR_SESSION_TOKEN to run live API integration test.")
        }

        let api = CursorAPIService()
        let usage = try await api.fetchUsage(sessionToken: token)

        XCTAssertFalse(usage.subscriptionPlan.isEmpty)
        XCTAssertGreaterThanOrEqual(usage.fastRequestsTotal, 0)
        XCTAssertGreaterThanOrEqual(usage.fastRequestsUsed, 0)
    }
}
