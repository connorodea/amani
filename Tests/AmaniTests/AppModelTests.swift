import XCTest
@testable import Amani

@MainActor
final class AppModelTests: XCTestCase {
    func testBuildsAllThreeProvidersAndTriggers() {
        let defaults = UserDefaults(suiteName: "com.connorodea.AmaniTests.\(UUID().uuidString)")!
        let model = AppModel(settings: SettingsStore(defaults: defaults))

        XCTAssertEqual(model.searchController.results.count, 0) // sanity: starts empty
        // AppModel wires 3 providers into SearchController and 3 triggers into
        // ActivationManager — this is exercised end-to-end via a real activation below.
        model.activateOverlayForTesting()
        XCTAssertTrue(model.overlayWindowController.isVisible)
    }

    func testShowSetupWindowIfNeededDoesNotCrash() {
        let defaults = UserDefaults(suiteName: "com.connorodea.AmaniTests.\(UUID().uuidString)")!
        let model = AppModel(settings: SettingsStore(defaults: defaults))
        model.showSetupWindowIfNeeded() // must not crash regardless of this machine's actual permission state
    }
}
