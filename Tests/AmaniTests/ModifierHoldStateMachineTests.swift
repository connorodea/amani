import XCTest
@testable import Amani

final class ModifierHoldStateMachineTests: XCTestCase {
    func testHoldingAloneToThresholdFires() {
        var machine = ModifierHoldStateMachine(thresholdSeconds: 5.0)
        XCTAssertEqual(machine.modifierDown(at: 0.0), .none)
        XCTAssertEqual(machine.tick(at: 4.9), .none)
        XCTAssertEqual(machine.tick(at: 5.0), .fire)
    }

    func testFiresOnlyOncePerHold() {
        var machine = ModifierHoldStateMachine(thresholdSeconds: 5.0)
        _ = machine.modifierDown(at: 0.0)
        XCTAssertEqual(machine.tick(at: 5.0), .fire)
        XCTAssertEqual(machine.tick(at: 6.0), .none) // already fired this hold
    }

    func testOtherKeyDuringHoldCancels() {
        var machine = ModifierHoldStateMachine(thresholdSeconds: 5.0)
        _ = machine.modifierDown(at: 0.0)
        XCTAssertEqual(machine.otherKeyOrModifierEvent(at: 2.0), .cancelled)
        XCTAssertEqual(machine.tick(at: 5.0), .none) // hold was cancelled, threshold no longer applies
    }

    func testEarlyReleaseCancels() {
        var machine = ModifierHoldStateMachine(thresholdSeconds: 5.0)
        _ = machine.modifierDown(at: 0.0)
        XCTAssertEqual(machine.modifierUp(at: 2.0), .cancelled)
        XCTAssertEqual(machine.tick(at: 5.0), .none)
    }

    func testReleaseAfterFireIsNotAnError() {
        var machine = ModifierHoldStateMachine(thresholdSeconds: 5.0)
        _ = machine.modifierDown(at: 0.0)
        XCTAssertEqual(machine.tick(at: 5.0), .fire)
        XCTAssertEqual(machine.modifierUp(at: 5.1), .none)
    }

    func testNewHoldAfterReleaseWorksAgain() {
        var machine = ModifierHoldStateMachine(thresholdSeconds: 5.0)
        _ = machine.modifierDown(at: 0.0)
        _ = machine.modifierUp(at: 1.0) // cancelled, released early
        _ = machine.modifierDown(at: 10.0)
        XCTAssertEqual(machine.tick(at: 15.0), .fire)
    }
}
