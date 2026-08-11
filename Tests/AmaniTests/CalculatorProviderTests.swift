import XCTest
@testable import Amani

final class CalculatorProviderTests: XCTestCase {
    let provider = CalculatorProvider()

    func testSimpleAddition() {
        let results = provider.results(for: "2 + 2")
        XCTAssertEqual(results.first?.title, "4")
    }

    func testOrderOfOperations() {
        let results = provider.results(for: "2 + 3 * 4")
        XCTAssertEqual(results.first?.title, "14")
    }

    func testParentheses() {
        let results = provider.results(for: "(2 + 3) * 4")
        XCTAssertEqual(results.first?.title, "20")
    }

    func testDecimals() {
        let results = provider.results(for: "1.5 + 2.5")
        XCTAssertEqual(results.first?.title, "4")
    }

    func testDivisionByZeroReturnsNoResult() {
        let results = provider.results(for: "1 / 0")
        XCTAssertTrue(results.isEmpty)
    }

    func testNonNumericQueryReturnsNoResult() {
        let results = provider.results(for: "Xcode")
        XCTAssertTrue(results.isEmpty)
    }

    func testMalformedExpressionReturnsNoResult() {
        let results = provider.results(for: "2 + + 3")
        XCTAssertTrue(results.isEmpty)
    }
}
