import XCTest
@testable import Amani

final class OrbStateTests: XCTestCase {
    func testActiveStateRotatesFasterAndGlowsMoreThanIdle() {
        let idle = OrbState.idle.animationParameters
        let active = OrbState.active.animationParameters

        XCTAssertGreaterThan(active.rotationSpeed, idle.rotationSpeed)
        XCTAssertGreaterThan(active.glowIntensity, idle.glowIntensity)
    }
}
