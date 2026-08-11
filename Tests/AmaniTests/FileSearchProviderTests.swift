import XCTest
@testable import Amani

private final class FakeShellRunner: ShellRunning {
    var output = ""
    var lastExecutable: String?
    var lastArguments: [String]?

    func run(_ executable: String, arguments: [String]) -> String {
        lastExecutable = executable
        lastArguments = arguments
        return output
    }
}

final class FileSearchProviderTests: XCTestCase {
    func testShortQueryReturnsNoResults() {
        let shell = FakeShellRunner()
        let provider = FileSearchProvider(shell: shell)
        XCTAssertTrue(provider.results(for: "a").isEmpty)
        XCTAssertNil(shell.lastExecutable)
    }

    func testParsesMdfindOutputIntoResults() {
        let shell = FakeShellRunner()
        shell.output = "/Users/connor/report.pdf\n/Users/connor/Documents/report-notes.txt\n"
        let provider = FileSearchProvider(shell: shell)

        let results = provider.results(for: "report")

        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].title, "report.pdf")
        XCTAssertEqual(results[0].subtitle, "/Users/connor/report.pdf")
        XCTAssertEqual(results[0].action, .openFile(path: "/Users/connor/report.pdf"))
    }

    func testCallsMdfindWithNameFlag() {
        let shell = FakeShellRunner()
        let provider = FileSearchProvider(shell: shell)
        _ = provider.results(for: "report")
        XCTAssertEqual(shell.lastExecutable, "/usr/bin/mdfind")
        XCTAssertEqual(shell.lastArguments, ["-name", "report"])
    }

    func testEmptyOutputReturnsNoResults() {
        let shell = FakeShellRunner()
        shell.output = ""
        let provider = FileSearchProvider(shell: shell)
        XCTAssertTrue(provider.results(for: "report").isEmpty)
    }
}
