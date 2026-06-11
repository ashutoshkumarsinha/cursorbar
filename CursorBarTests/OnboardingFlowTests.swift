import XCTest
@testable import CursorBar

@MainActor
final class OnboardingFlowTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        super.tearDown()
    }

    func testStoreStartsExpiredWhenKeychainEmpty() {
        let keychain = KeychainService(
            service: "com.cursorbar.tests.\(UUID().uuidString)",
            account: "WorkosCursorSessionToken"
        )
        let store = UsageStore(
            config: .default,
            keychain: keychain,
            api: CursorAPIService(config: .default, session: MockURLSessionFactory.make())
        )

        XCTAssertTrue(store.state.isSessionExpired)
        XCTAssertEqual(store.gaugeStatus, .warning)
    }

    func testSaveTokenTransitionsToSuccess() async throws {
        let summaryData = try Data(contentsOf: fixtureURL(named: "usage-summary"))
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            if request.url?.path.contains("usage-summary") == true {
                return (response, summaryData)
            }
            return (response, Data("{}".utf8))
        }

        let keychain = KeychainService(
            service: "com.cursorbar.tests.\(UUID().uuidString)",
            account: "WorkosCursorSessionToken"
        )
        let store = UsageStore(
            config: .default,
            keychain: keychain,
            api: CursorAPIService(config: .default, session: MockURLSessionFactory.make())
        )

        try store.saveSessionToken("integration-token")
        await store.syncNow()

        guard case .success(let usage) = store.state else {
            return XCTFail("Expected success state, got \(store.state)")
        }
        XCTAssertEqual(usage.subscriptionPlan, "Pro")
        XCTAssertEqual(store.gaugeStatus, .green)
    }

    private func fixtureURL(named name: String) throws -> URL {
        let bundle = Bundle(for: OnboardingFlowTests.self)
        if let url = bundle.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")
            ?? bundle.url(forResource: name, withExtension: "json") {
            return url
        }
        throw XCTSkip("Fixture \(name).json not in test bundle")
    }
}
