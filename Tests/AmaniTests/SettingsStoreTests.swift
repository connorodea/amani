import XCTest
@testable import Amani

final class SettingsStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var store: SettingsStore!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "com.connorodea.AmaniTests.\(UUID().uuidString)")
        store = SettingsStore(defaults: defaults)
    }

    func testDefaultsAllTriggersEnabled() {
        XCTAssertTrue(store.isTriggerEnabled(.hotkey))
        XCTAssertTrue(store.isTriggerEnabled(.modifierHold))
        XCTAssertTrue(store.isTriggerEnabled(.menuBar))
    }

    func testDefaultModifierHoldDuration() {
        XCTAssertEqual(store.modifierHoldDurationSeconds, 5.0)
    }

    func testTogglingPersists() {
        store.setTriggerEnabled(.modifierHold, enabled: false)
        let reloaded = SettingsStore(defaults: defaults)
        XCTAssertFalse(reloaded.isTriggerEnabled(.modifierHold))
        XCTAssertTrue(reloaded.isTriggerEnabled(.hotkey))
    }

    func testSettingHoldDurationPersists() {
        store.modifierHoldDurationSeconds = 3.5
        let reloaded = SettingsStore(defaults: defaults)
        XCTAssertEqual(reloaded.modifierHoldDurationSeconds, 3.5)
    }
}
