import AppKit
import Foundation

struct AppEntry: Equatable {
    let name: String
    let bundleURL: URL
}

protocol AppEnumerating {
    func enumerateApps() -> [AppEntry]
}

final class NSWorkspaceAppEnumerator: AppEnumerating {
    private let searchDirectories = [
        "/Applications",
        "/System/Applications",
        "\(NSHomeDirectory())/Applications",
    ]

    func enumerateApps() -> [AppEntry] {
        var entries: [AppEntry] = []
        let fileManager = FileManager.default
        for directory in searchDirectories {
            guard let items = try? fileManager.contentsOfDirectory(atPath: directory) else { continue }
            for item in items where item.hasSuffix(".app") {
                let url = URL(fileURLWithPath: directory).appendingPathComponent(item)
                let name = (item as NSString).deletingPathExtension
                entries.append(AppEntry(name: name, bundleURL: url))
            }
        }
        return entries
    }
}

final class AppLauncherProvider: ResultProvider {
    let id = "app-launcher"
    private let enumerator: AppEnumerating
    private var cache: [AppEntry] = []
    private let maxResults = 8

    init(enumerator: AppEnumerating = NSWorkspaceAppEnumerator()) {
        self.enumerator = enumerator
        refreshCache()
    }

    func refreshCache() {
        cache = enumerator.enumerateApps()
    }

    func results(for query: String) -> [SearchResult] {
        guard !query.isEmpty else { return [] }
        let scored = cache.compactMap { entry -> (AppEntry, Double)? in
            guard let score = FuzzyMatch.score(query: query, target: entry.name) else { return nil }
            return (entry, score)
        }
        let sorted = scored.sorted { $0.1 > $1.1 }.prefix(maxResults)
        return sorted.map { entry, score in
            SearchResult(
                id: "app:\(entry.bundleURL.path)",
                title: entry.name,
                subtitle: entry.bundleURL.path,
                icon: .app(bundleURL: entry.bundleURL),
                score: score,
                action: .launchApp(bundleURL: entry.bundleURL)
            )
        }
    }
}
