import Foundation

protocol ShellRunning {
    func run(_ executable: String, arguments: [String]) -> String
}

final class ProcessShellRunner: ShellRunning {
    func run(_ executable: String, arguments: [String]) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return ""
        }
        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(data: data, encoding: .utf8) ?? ""
    }
}

final class FileSearchProvider: ResultProvider {
    let id = "file-search"
    private let shell: ShellRunning
    private let maxResults = 8
    private let minimumQueryLength = 2

    init(shell: ShellRunning = ProcessShellRunner()) {
        self.shell = shell
    }

    func results(for query: String) -> [SearchResult] {
        guard query.count >= minimumQueryLength else { return [] }
        let output = shell.run("/usr/bin/mdfind", arguments: ["-name", query])
        let paths = output
            .split(separator: "\n")
            .map(String.init)
            .filter { !$0.isEmpty }
            .prefix(maxResults)

        return paths.map { path in
            let name = (path as NSString).lastPathComponent
            return SearchResult(
                id: "file:\(path)",
                title: name,
                subtitle: path,
                icon: .file(path: path),
                score: 0.5,
                action: .openFile(path: path)
            )
        }
    }
}
