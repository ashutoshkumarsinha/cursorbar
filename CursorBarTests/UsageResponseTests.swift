import XCTest
@testable import CursorBar

final class UsageResponseTests: XCTestCase {
    func testDecodesFixtureJSON() throws {
        let data = try loadFixture(named: "usage")
        let usage = try JSONDecoder().decode(UsageResponse.self, from: data)

        XCTAssertEqual(usage.subscriptionPlan, "Pro")
        XCTAssertEqual(usage.fastRequestsRemaining, 350)
        XCTAssertEqual(usage.modelBreakdown.count, 2)
        XCTAssertEqual(usage.modelBreakdown[0].displayName, "Claude 4.6 Opus")
        XCTAssertEqual(usage.modelBreakdown[0].formattedTokenCount, "1.57M")
    }

    func testModelUsageFormatsThousands() {
        let model = ModelUsage(modelName: "gpt-5-fast", inputTokens: 10_000, outputTokens: 500)
        XCTAssertEqual(model.formattedTokenCount, "10.5K")
    }

    private func loadFixture(named name: String) throws -> Data {
        let bundle = Bundle(for: UsageResponseTests.self)
        let url = bundle.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")
            ?? bundle.url(forResource: name, withExtension: "json")
        guard let url else {
            throw XCTSkip("Fixture \(name).json not in test bundle")
        }
        return try Data(contentsOf: url)
    }
}
