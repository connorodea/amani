import XCTest
@testable import Amani

private struct FakeAppEnumerator: AppEnumerating {
    let entries: [AppEntry]
    func enumerateApps() -> [AppEntry] { entries }
}

final class FuzzyMatchTests: XCTestCase {
    func testExactPrefixScoresHighest() {
        let prefixScore = FuzzyMatch.score(query: "saf", target: "Safari")!
        let subsequenceScore = FuzzyMatch.score(query: "sfr", target: "Safari")!
        XCTAssertGreaterThan(prefixScore, subsequenceScore)
    }

    func testNonMatchingReturnsNil() {
        XCTAssertNil(FuzzyMatch.score(query: "zzz", target: "Safari"))
    }

    func testCaseInsensitive() {
        XCTAssertNotNil(FuzzyMatch.score(query: "SAF", target: "safari"))
    }
}

final class AppLauncherProviderTests: XCTestCase {
    func testFindsMatchingAppsSortedByScore() {
        let entries = [
            AppEntry(name: "Safari", bundleURL: URL(fileURLWithPath: "/Applications/Safari.app")),
            AppEntry(name: "Xcode", bundleURL: URL(fileURLWithPath: "/Applications/Xcode.app")),
            AppEntry(name: "Slack", bundleURL: URL(fileURLWithPath: "/Applications/Slack.app")),
        ]
        let provider = AppLauncherProvider(enumerator: FakeAppEnumerator(entries: entries))

        let results = provider.results(for: "s")

        XCTAssertEqual(results.map(\.title), ["Safari", "Slack"])
    }

    func testEmptyQueryReturnsNoResults() {
        let provider = AppLauncherProvider(enumerator: FakeAppEnumerator(entries: []))
        XCTAssertTrue(provider.results(for: "").isEmpty)
    }

    func testResultActionIsLaunchApp() {
        let entries = [AppEntry(name: "Safari", bundleURL: URL(fileURLWithPath: "/Applications/Safari.app"))]
        let provider = AppLauncherProvider(enumerator: FakeAppEnumerator(entries: entries))

        let result = provider.results(for: "safari").first!

        XCTAssertEqual(result.action, .launchApp(bundleURL: URL(fileURLWithPath: "/Applications/Safari.app")))
    }
}
