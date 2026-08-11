import XCTest
import Carbon
@testable import Amani

final class HotkeyComboTests: XCTestCase {
    func testCmdSpaceProducesCorrectCarbonModifiers() {
        let combo = HotkeyCombo.default
        XCTAssertEqual(combo.carbonModifiers, UInt32(cmdKey))
        XCTAssertEqual(combo.keyCode, UInt32(kVK_Space))
    }
}
