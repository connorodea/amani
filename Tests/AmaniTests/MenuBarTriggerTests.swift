import XCTest
@testable import Amani

@MainActor
final class MenuBarTriggerTests: XCTestCase {
    func testStartThenSimulatedClickFiresCallback() {
        let trigger = MenuBarTrigger()
        var activated = false
        trigger.start { activated = true }

        trigger.simulateClickForTesting()

        XCTAssertTrue(activated)
    }

    func testStopPreventsFurtherActivation() {
        let trigger = MenuBarTrigger()
        var activationCount = 0
        trigger.start { activationCount += 1 }
        trigger.simulateClickForTesting()
        trigger.stop()

        trigger.simulateClickForTesting()

        XCTAssertEqual(activationCount, 1)
    }
}
