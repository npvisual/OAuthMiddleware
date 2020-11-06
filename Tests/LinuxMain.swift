import XCTest

import OAuthMiddlewareTests

var tests = [XCTestCaseEntry]()
tests += OAuthMiddlewareTests.allTests()
XCTMain(tests)
