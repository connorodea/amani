import XCTest
@testable import Amani

@MainActor
private final class FakeTrigger: ActivationTrigger {
    let id: String
    private(set) var isStarted = false
    private var onActivate: (() -> Void)?

    init(id: String) { self.id = id }

    func start(onActivate: @escaping () -> Void) {
        isStarted = true
        self.onActivate = onActivate
    }

    func stop() {
        isStarted = false
        onActivate = nil
    }

    func fireForTesting() {
        onActivate?()
    }
}

@MainActor
final class ActivationManagerTests: XCTestCase {
    func testStartsOnlyEnabledTriggers() {
        let defaults = UserDefaults(suiteName: "com.connorodea.AmaniTests.\(UUID().uuidString)")!
        let store = SettingsStore(defaults: defaults)
        store.setTriggerEnabled(.hotkey, enabled: false)

        let hotkey = FakeTrigger(id: TriggerKind.hotkey.rawValue)
        let modifierHold = FakeTrigger(id: TriggerKind.modifierHold.rawValue)
        let manager = ActivationManager(triggers: [hotkey, modifierHold], settings: store, onActivate: {})

        manager.start()

        XCTAssertFalse(hotkey.isStarted)
        XCTAssertTrue(modifierHold.isStarted)
    }

    func testAnyTriggerFiringCallsSharedCallback() {
        let defaults = UserDefaults(suiteName: "com.connorodea.AmaniTests.\(UUID().uuidString)")!
        let store = SettingsStore(defaults: defaults)
        let trigger = FakeTrigger(id: TriggerKind.menuBar.rawValue)
        var activationCount = 0
        let manager = ActivationManager(triggers: [trigger], settings: store, onActivate: { activationCount += 1 })

        manager.start()
        trigger.fireForTesting()
        trigger.fireForTesting()

        XCTAssertEqual(activationCount, 2)
    }

    func testStartAgainRestartsATriggerThatFailedItsFirstStart() {
        // Mirrors ModifierHoldTrigger: its real start() silently no-ops if Input Monitoring
        // isn't granted yet, and nothing previously re-invoked start() after the user granted
        // the permission mid-session — Setup's "refresh" button now calls ActivationManager
        // .start() again, which must actually restart the trigger that didn't start the first
        // time, not just leave it permanently dead until relaunch.
        let defaults = UserDefaults(suiteName: "com.connorodea.AmaniTests.\(UUID().uuidString)")!
        let store = SettingsStore(defaults: defaults)
        let trigger = FakeTrigger(id: TriggerKind.modifierHold.rawValue)
        let manager = ActivationManager(triggers: [trigger], settings: store, onActivate: {})

        manager.start()
        XCTAssertTrue(trigger.isStarted)
        trigger.stop() // simulate the real trigger's own guard bailing out silently
        XCTAssertFalse(trigger.isStarted)

        manager.start()
        XCTAssertTrue(trigger.isStarted)
    }

    func testStopStopsAllTriggers() {
        let defaults = UserDefaults(suiteName: "com.connorodea.AmaniTests.\(UUID().uuidString)")!
        let store = SettingsStore(defaults: defaults)
        let a = FakeTrigger(id: TriggerKind.hotkey.rawValue)
        let b = FakeTrigger(id: TriggerKind.menuBar.rawValue)
        let manager = ActivationManager(triggers: [a, b], settings: store, onActivate: {})

        manager.start()
        manager.stop()

        XCTAssertFalse(a.isStarted)
        XCTAssertFalse(b.isStarted)
    }
}
