import XCTest
@testable import CursorBar

final class SessionTokenNormalizerTests: XCTestCase {
    func testNormalizesDoubleColonCookie() {
        let jwt = "eyJ.test.signature"
        XCTAssertEqual(
            SessionTokenNormalizer.cookieValue(from: "user_abc::\(jwt)"),
            "user_abc%3A%3A\(jwt)"
        )
    }

    func testBearerFromCookieValue() {
        let jwt = "eyJ.test.signature"
        XCTAssertEqual(
            SessionTokenNormalizer.bearerToken(from: "user_abc%3A%3A\(jwt)"),
            jwt
        )
    }
}
