import Foundation

protocol ShellRunning {
    func run(_ executable: String, arguments: [String]) -> String
}

final class ProcessShellRunner: ShellRunning {
    private let timeoutSeconds: TimeInterval

    init(timeoutSeconds: TimeInterval = 2.0) {
        self.timeoutSeconds = timeoutSeconds
    }

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

        // SearchController's per-provider timeout only stops *waiting* on this call's result —
        // it doesn't touch the underlying process. mdfind can hang during Spotlight reindexing
        // or on a flaky volume; without this, that would pin this thread (and its slot on the
        // shared dispatch queue other providers also use) indefinitely.
        let watchdog = DispatchWorkItem { [weak process] in
            guard let process, process.isRunning else { return }
            process.terminate()
        }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeoutSeconds, execute: watchdog)

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        watchdog.cancel()
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
