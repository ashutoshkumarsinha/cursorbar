import XCTest
@testable import CursorBar

final class KeychainServiceTests: XCTestCase {
    private var keychain: KeychainService!

    override func setUp() {
        super.setUp()
        keychain = KeychainService(
            service: "com.cursorbar.tests.\(UUID().uuidString)",
            account: "WorkosCursorSessionToken"
        )
        try? keychain.deleteSessionToken()
    }

    override func tearDown() {
        try? keychain.deleteSessionToken()
        super.tearDown()
    }

    func testRoundTripToken() throws {
        XCTAssertFalse(keychain.hasToken)
        try keychain.saveSessionToken("session-123")
        XCTAssertTrue(keychain.hasToken)
        XCTAssertEqual(try keychain.readSessionToken(), "session-123")
    }

    func testDeleteRemovesToken() throws {
        try keychain.saveSessionToken("session-123")
        try keychain.deleteSessionToken()
        XCTAssertFalse(keychain.hasToken)
        XCTAssertNil(try keychain.readSessionToken())
    }
}
