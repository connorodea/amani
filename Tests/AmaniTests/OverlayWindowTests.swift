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

    func testShowRecordsActivationOnSearchController() {
        let searchController = SearchController(providers: [])
        let controller = OverlayWindowController(searchController: searchController)
        controller.show()
        XCTAssertEqual(searchController.activationTick, 1)
    }

    func testEachShowRecordsANewActivationEvenWhenPanelIsReused() {
        // The panel/hosting view are created once and reused across show/hide cycles, so the
        // view can't rely on a one-shot `.onAppear` to refocus the search field on reopen —
        // `activationTick` is the mechanism that fires on every show(), not just the first.
        let searchController = SearchController(providers: [])
        let controller = OverlayWindowController(searchController: searchController)
        controller.show()
        controller.hide()
        controller.show()
        XCTAssertEqual(searchController.activationTick, 2)
    }

    func testRapidHideThenShowLeavesStateVisible() {
        // Regression guard: hide()'s animation completion is deferred, so a rapid hide()
        // immediately followed by show() (double-tapping the toggle hotkey) must not let the
        // stale hide's completion handler override the newer show()'s state.
        let controller = OverlayWindowController()
        controller.show()
        controller.hide()
        controller.show()
        XCTAssertTrue(controller.isVisible)
    }
}
