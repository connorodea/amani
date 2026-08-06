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
}
