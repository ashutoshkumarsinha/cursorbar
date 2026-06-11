import XCTest
@testable import CursorBar

final class ConfigLoaderTests: XCTestCase {
    func testParseAppliesDocumentedDefaults() {
        let config = ConfigLoader.parse("""
        [polling]
        refresh_interval_minutes = 30
        pause_on_sleep = false
        sync_on_wake = false

        [menu_bar]
        display_spending = true

        [api]
        base_url = "https://example.com/api/usage"
        user_agent = "TestAgent/1.0"

        [gauge]
        red_requests_remaining = 25
        orange_quota_percent = 10
        orange_spend_percent = 90

        [logging]
        level = "debug"
        """)

        XCTAssertEqual(config.refreshIntervalMinutes, 30)
        XCTAssertFalse(config.pauseOnSleep)
        XCTAssertFalse(config.syncOnWake)
        XCTAssertTrue(config.displaySpending)
        XCTAssertEqual(config.apiBaseURL, "https://example.com/api/usage")
        XCTAssertEqual(config.userAgent, "TestAgent/1.0")
        XCTAssertEqual(config.gaugeThresholds.redRequestsRemaining, 25)
        XCTAssertEqual(config.gaugeThresholds.orangeQuotaPercent, 10)
        XCTAssertEqual(config.gaugeThresholds.orangeSpendPercent, 90)
        XCTAssertEqual(config.loggingLevel, "debug")
    }

    func testParseIgnoresCommentsAndInvalidInterval() {
        let config = ConfigLoader.parse("""
        # leading comment
        [polling]
        refresh_interval_minutes = 7 # unsupported, keep default
        """)

        XCTAssertEqual(config.refreshIntervalMinutes, 15)
    }

    func testLoadMissingFileReturnsDefault() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("missing-cursorbar-config.toml")
        XCTAssertEqual(ConfigLoader.load(from: url), .default)
    }
}
