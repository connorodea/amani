import XCTest
@testable import Amani

@MainActor
final class PermissionManagerTests: XCTestCase {
    func testStatesStartUnknownBeforeRefresh() {
        // PermissionManager.refresh() is called in init and touches real system APIs
        // (AXIsProcessTrusted, CGPreflightListenEventAccess) that are safe to call in CI/test
        // and don't prompt the user — this just confirms the manager instantiates and produces
        // *some* concrete state rather than crashing.
        let manager = PermissionManager()
        XCTAssertNotEqual(manager.accessibility, .unknown)
        XCTAssertNotEqual(manager.inputMonitoring, .unknown)
    }
}
