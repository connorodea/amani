import XCTest
@testable import Amani

@MainActor
final class OverlayWindowControllerTests: XCTestCase {
    func testStartsHidden() {
        let controller = OverlayWindowController()
        XCTAssertFalse(controller.isVisible)
    }

    func testToggleShowsThenHides() {
        let controller = OverlayWindowController()
        controller.toggle()
        XCTAssertTrue(controller.isVisible)
        controller.toggle()
        XCTAssertFalse(controller.isVisible)
    }

    func testHideWhenAlreadyHiddenIsSafe() {
        let controller = OverlayWindowController()
        controller.hide()
        XCTAssertFalse(controller.isVisible)
    }
}
