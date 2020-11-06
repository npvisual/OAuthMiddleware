import XCTest
@testable import OAuthMiddleware

final class OAuthMiddlewareTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(OAuthMiddleware().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
