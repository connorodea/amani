import XCTest
@testable import Amani

final class SmokeTests: XCTestCase {
    func testAppDelegateInstantiates() {
        let delegate = AppDelegate()
        XCTAssertNotNil(delegate)
    }
}
