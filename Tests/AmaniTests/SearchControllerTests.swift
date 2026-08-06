import XCTest
@testable import Amani

private final class FakeProvider: ResultProvider {
    let id: String
    let fixedResults: [SearchResult]
    let delayMilliseconds: Int

    init(id: String, results: [SearchResult], delayMilliseconds: Int = 0) {
        self.id = id
        self.fixedResults = results
        self.delayMilliseconds = delayMilliseconds
    }

    func results(for query: String) -> [SearchResult] {
        if delayMilliseconds > 0 {
            Thread.sleep(forTimeInterval: Double(delayMilliseconds) / 1000.0)
        }
        return fixedResults
    }
}

@MainActor
final class SearchControllerTests: XCTestCase {
    func testEmptyQueryProducesEmptyResults() {
        let controller = SearchController(providers: [], debounceMilliseconds: 0, providerTimeoutMilliseconds: 200)
        let expectation = expectation(description: "search completes")
        controller.performSearch("") {
            XCTAssertTrue(controller.results.isEmpty)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    func testMergesResultsFromMultipleProviders() {
        let a = FakeProvider(id: "a", results: [
            SearchResult(id: "a1", title: "A1", subtitle: "", icon: .system(symbolName: "a"), score: 0.5, action: .copyToClipboard("a"))
        ])
        let b = FakeProvider(id: "b", results: [
            SearchResult(id: "b1", title: "B1", subtitle: "", icon: .system(symbolName: "b"), score: 0.9, action: .copyToClipboard("b"))
        ])
        let controller = SearchController(providers: [a, b], debounceMilliseconds: 0, providerTimeoutMilliseconds: 200)

        let expectation = expectation(description: "search completes")
        controller.performSearch("q") {
            XCTAssertEqual(controller.results.map(\.id), ["b1", "a1"]) // sorted by score desc
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    func testSlowProviderIsExcludedAfterTimeout() {
        let fast = FakeProvider(id: "fast", results: [
            SearchResult(id: "fast1", title: "Fast", subtitle: "", icon: .system(symbolName: "f"), score: 0.5, action: .copyToClipboard("f"))
        ])
        let slow = FakeProvider(id: "slow", results: [
            SearchResult(id: "slow1", title: "Slow", subtitle: "", icon: .system(symbolName: "s"), score: 0.9, action: .copyToClipboard("s"))
        ], delayMilliseconds: 300)
        let controller = SearchController(providers: [fast, slow], debounceMilliseconds: 0, providerTimeoutMilliseconds: 50)

        let expectation = expectation(description: "search completes")
        controller.performSearch("q") {
            XCTAssertEqual(controller.results.map(\.id), ["fast1"])
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - Selection

    private func threeResultController() -> SearchController {
        let provider = FakeProvider(id: "p", results: [
            SearchResult(id: "1", title: "One", subtitle: "", icon: .system(symbolName: "1"), score: 0.9, action: .copyToClipboard("1")),
            SearchResult(id: "2", title: "Two", subtitle: "", icon: .system(symbolName: "2"), score: 0.8, action: .copyToClipboard("2")),
            SearchResult(id: "3", title: "Three", subtitle: "", icon: .system(symbolName: "3"), score: 0.7, action: .copyToClipboard("3")),
        ])
        return SearchController(providers: [provider], debounceMilliseconds: 0, providerTimeoutMilliseconds: 200)
    }

    private func populateResults(_ controller: SearchController, query: String = "q") {
        let expectation = expectation(description: "search completes")
        controller.performSearch(query) { expectation.fulfill() }
        wait(for: [expectation], timeout: 1.0)
    }

    func testMoveSelectionAdvancesAndClampsAtEnd() {
        let controller = threeResultController()
        populateResults(controller)

        controller.moveSelection(by: 1)
        XCTAssertEqual(controller.selectedIndex, 1)

        controller.moveSelection(by: 1)
        controller.moveSelection(by: 1) // would go to 3, out of bounds for a 3-item list
        XCTAssertEqual(controller.selectedIndex, 2)
    }

    func testMoveSelectionClampsAtStart() {
        let controller = threeResultController()
        populateResults(controller)

        controller.moveSelection(by: -1)
        XCTAssertEqual(controller.selectedIndex, 0)
    }

    func testMoveSelectionIsNoOpWithNoResults() {
        let controller = SearchController(providers: [], debounceMilliseconds: 0, providerTimeoutMilliseconds: 200)
        controller.moveSelection(by: 1)
        XCTAssertEqual(controller.selectedIndex, 0)
    }

    func testSelectedResultReflectsSelectedIndex() {
        let controller = threeResultController()
        populateResults(controller)

        controller.moveSelection(by: 1)
        XCTAssertEqual(controller.selectedResult?.id, "2")
    }

    func testSelectedResultIsNilWithNoResults() {
        let controller = SearchController(providers: [], debounceMilliseconds: 0, providerTimeoutMilliseconds: 200)
        XCTAssertNil(controller.selectedResult)
    }

    func testSelectedIndexResetsWhenResultsChange() {
        let controller = threeResultController()
        populateResults(controller)
        controller.moveSelection(by: 1)
        XCTAssertEqual(controller.selectedIndex, 1)

        populateResults(controller, query: "q2") // same provider, fresh performSearch call
        XCTAssertEqual(controller.selectedIndex, 0)
    }
}
