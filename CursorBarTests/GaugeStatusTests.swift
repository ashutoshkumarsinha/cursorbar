import XCTest
@testable import CursorBar

final class GaugeStatusTests: XCTestCase {
    private let thresholds = GaugeThresholds(
        redRequestsRemaining: 50,
        orangeQuotaPercent: 20,
        orangeSpendPercent: 80
    )

    func testGreenWhenQuotaHealthy() {
        let usage = makeUsage(used: 100, total: 500, spend: 1, limit: 20)
        XCTAssertEqual(GaugeStatus.from(usage: usage, thresholds: thresholds), .green)
    }

    func testRedWhenRequestsBelowThreshold() {
        let usage = makeUsage(used: 460, total: 500, spend: 0, limit: 20)
        XCTAssertEqual(GaugeStatus.from(usage: usage, thresholds: thresholds), .red)
    }

    func testOrangeWhenQuotaLow() {
        let usage = makeUsage(used: 410, total: 500, spend: 0, limit: 20)
        XCTAssertEqual(GaugeStatus.from(usage: usage, thresholds: thresholds), .orange)
    }

    func testOrangeWhenSpendHigh() {
        let usage = makeUsage(used: 100, total: 500, spend: 17, limit: 20)
        XCTAssertEqual(GaugeStatus.from(usage: usage, thresholds: thresholds), .orange)
    }

    private func makeUsage(
        used: Int,
        total: Int,
        spend: Double,
        limit: Double
    ) -> UsageResponse {
        UsageResponse(
            subscriptionPlan: "Pro",
            daysLeftInPeriod: 10,
            fastRequestsUsed: used,
            fastRequestsTotal: total,
            optionalSpendingLimit: limit,
            optionalSpendingCurrent: spend,
            modelBreakdown: []
        )
    }
}
