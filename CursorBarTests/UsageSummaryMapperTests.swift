import XCTest
@testable import CursorBar

final class UsageSummaryMapperTests: XCTestCase {
    func testMapsUsageSummaryToUsageResponse() throws {
        let data = try loadFixture(named: "usage-summary")
        let summary = try JSONDecoder().decode(UsageSummaryResponse.self, from: data)
        let usage = UsageResponseMapper.from(summary: summary)

        XCTAssertEqual(usage.subscriptionPlan, "Pro")
        XCTAssertEqual(usage.fastRequestsUsed, 150)
        XCTAssertEqual(usage.fastRequestsTotal, 500)
        XCTAssertEqual(usage.fastRequestsRemaining, 350)
        XCTAssertEqual(usage.optionalSpendingCurrent, 4.52, accuracy: 0.01)
        XCTAssertEqual(usage.optionalSpendingLimit, 20.0, accuracy: 0.01)
    }

    private func loadFixture(named name: String) throws -> Data {
        let bundle = Bundle(for: UsageSummaryMapperTests.self)
        let url = bundle.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")
            ?? bundle.url(forResource: name, withExtension: "json")
        guard let url else {
            throw XCTSkip("Fixture \(name).json not in test bundle")
        }
        return try Data(contentsOf: url)
    }
}
